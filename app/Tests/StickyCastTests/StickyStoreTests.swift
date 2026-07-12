import XCTest
@testable import StickyCastCore

final class StickyStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)

    override func setUp() {
        defaults = UserDefaults(suiteName: "test.stickycast")!
        defaults.removePersistentDomain(forName: "test.stickycast")
    }

    func makeStore() -> StickyStore { StickyStore(defaults: defaults, screenFrame: screen) }

    func testAddPlacesTopRightThenCascades() {
        let store = makeStore()
        let a = try! store.add(content: "a").get()
        let b = try! store.add(content: "b").get()
        XCTAssertGreaterThan(a.frame.maxX, screen.width * 0.6)   // 우상단
        XCTAssertGreaterThan(a.frame.maxY, screen.height * 0.6)
        XCTAssertEqual(b.frame.origin.x, a.frame.origin.x - 24)  // 24px 캐스케이드
        XCTAssertEqual(b.frame.origin.y, a.frame.origin.y - 24)
    }

    func testCascadeWrapsWhenOffscreen() {
        let store = makeStore()
        var frames: [CGRect] = []
        for i in 0..<StickyStore.maxStickies {
            frames.append(try! store.add(content: "n\(i)").get().frame)
        }
        for f in frames { XCTAssertTrue(screen.contains(f), "\(f) offscreen") }
    }

    func testSoftCap() {
        let store = makeStore()
        for i in 0..<StickyStore.maxStickies { _ = store.add(content: "n\(i)") }
        if case .failure(let e) = store.add(content: "over") {
            XCTAssertEqual(e, .capReached)
        } else { XCTFail("cap 미적용") }
    }

    func testPersistRoundTrip() {
        let store = makeStore()
        let note = try! store.add(content: "안녕🎉").get()
        store.commitFrame(id: note.id, frame: CGRect(x: 10, y: 20, width: 300, height: 200))
        store.commitOpacity(id: note.id, opacity: 0.7)

        let store2 = makeStore()
        store2.restore()
        XCTAssertEqual(store2.notes.count, 1)
        XCTAssertEqual(store2.notes[0].content, "안녕🎉")
        XCTAssertEqual(store2.notes[0].frame, CGRect(x: 10, y: 20, width: 300, height: 200))
        XCTAssertEqual(store2.notes[0].opacity, 0.7)
    }

    func testRestoreIsolatesCorruptItems() {
        let good = """
        {"schemaVersion":1,"notes":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"ok",
           "frame":[[0,0],[100,100]],"opacity":1,"createdAt":0},
          {"id":"not-a-uuid","content":123}
        ]}
        """
        defaults.set(good.data(using: .utf8), forKey: "stickyStore.v1")
        let store = makeStore()
        store.restore()
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes[0].content, "ok")
    }

    func testUnsupportedSchemaVersionNotLoaded() {
        // schemaVersion 2 → 복원 건너뜀 (다운그레이드/손실 방지, iter-008)
        let future = """
        {"schemaVersion":2,"notes":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"future",
           "frame":[[0,0],[100,100]],"opacity":1,"createdAt":0}
        ]}
        """
        defaults.set(future.data(using: .utf8), forKey: "stickyStore.v1")
        let store = makeStore()
        store.restore()
        XCTAssertEqual(store.notes.count, 0)
    }

    func testRestoreIsolatesCorruptItems_badThenGood() {
        // 부패 항목이 먼저 와도 뒤의 정상 항목 생존 (순서 무관, iter-008)
        let json = """
        {"schemaVersion":1,"notes":[
          {"id":"not-a-uuid","content":123},
          {"id":"22222222-2222-2222-2222-222222222222","content":"good",
           "frame":[[0,0],[100,100]],"opacity":1,"createdAt":0}
        ]}
        """
        defaults.set(json.data(using: .utf8), forKey: "stickyStore.v1")
        let store = makeStore()
        store.restore()
        XCTAssertEqual(store.notes.count, 1)
        XCTAssertEqual(store.notes[0].content, "good")
    }

    func testRestoreClampsToCap() {
        // over-cap 저장 상태(35개)도 복원 시 maxStickies로 정규화 (iter-010)
        var notesJSON: [String] = []
        for i in 0..<35 {
            let uuid = String(format: "%08d-0000-0000-0000-000000000000", i)
            notesJSON.append("{\"id\":\"\(uuid)\",\"content\":\"n\(i)\",\"frame\":[[0,0],[100,100]],\"opacity\":1,\"createdAt\":0}")
        }
        let json = "{\"schemaVersion\":1,\"notes\":[\(notesJSON.joined(separator: ","))]}"
        defaults.set(json.data(using: .utf8), forKey: "stickyStore.v1")
        let store = makeStore()
        store.restore()
        XCTAssertEqual(store.notes.count, StickyStore.maxStickies)
    }

    func testRemovePersists() {
        let store = makeStore()
        let note = try! store.add(content: "a").get()
        store.remove(id: note.id)
        let store2 = makeStore()
        store2.restore()
        XCTAssertEqual(store2.notes.count, 0)
    }
}
