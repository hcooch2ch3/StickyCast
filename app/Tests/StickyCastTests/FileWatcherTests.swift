import XCTest
@testable import StickyCastCore

final class FileWatcherTests: XCTestCase {
    func testDetectsInPlaceWriteAndReArmsAfterAtomicSave() {
        let dir = NSTemporaryDirectory() + "fwtest-\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/n.md"
        try! "v0".write(toFile: path, atomically: false, encoding: .utf8)
        let w = FileWatcher()
        let exp = expectation(description: "change"); exp.expectedFulfillmentCount = 2
        exp.assertForOverFulfill = false   // watcher는 .write/.extend/재-arm으로 >2 발화 가능 → ≥2만 요구
        var events = 0
        w.watch(noteID: UUID(), url: URL(fileURLWithPath: path)) { events += 1; exp.fulfill() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if let h = FileHandle(forWritingAtPath: path) { h.seekToEndOfFile(); h.write(Data(" x".utf8)); try? h.close() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {   // atomic save
            let tmp = dir + "/.tmp"; try! "v1".write(toFile: tmp, atomically: false, encoding: .utf8)
            rename(tmp, path)
        }
        wait(for: [exp], timeout: 4)
        XCTAssertGreaterThanOrEqual(events, 2)
        w.unwatchAll()
        try? FileManager.default.removeItem(atPath: dir)
    }

    // Finding #1 회귀: rename으로 debounce 재-arm이 예약된 뒤 그 150ms 창 안에 unwatch하면
    // 예약이 취소돼 이후 어떤 ping도 오면 안 된다(좀비 감시 부활·헛 다이얼로그 방지).
    func testUnwatchDuringRearmWindowCancelsPendingRearm() {
        let dir = NSTemporaryDirectory() + "fwtest-\(UUID().uuidString)"
        try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/n.md"
        try! "v0".write(toFile: path, atomically: false, encoding: .utf8)
        let w = FileWatcher()
        let id = UUID()
        var unwatched = false
        var pingsAfterUnwatch = 0
        w.watch(noteID: id, url: URL(fileURLWithPath: path)) { if unwatched { pingsAfterUnwatch += 1 } }
        // rename 이벤트 발화 → +0.15s 재-arm 예약
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let tmp = dir + "/.tmp"; try! "v1".write(toFile: tmp, atomically: false, encoding: .utf8)
            rename(tmp, path)
        }
        // 재-arm 창(150ms) 안에서 unwatch
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            unwatched = true
            w.unwatch(noteID: id)
        }
        let done = expectation(description: "settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { done.fulfill() }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(pingsAfterUnwatch, 0, "unwatch 후 재-arm ping이 발화하면 안 됨")
        w.unwatchAll()
        try? FileManager.default.removeItem(atPath: dir)
    }
}
