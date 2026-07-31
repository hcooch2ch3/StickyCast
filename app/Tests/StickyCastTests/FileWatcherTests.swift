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
}
