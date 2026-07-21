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

    func testAddRejectsOversizeContent() {
        // 콘텐츠 바이트 캡: 정확히 한도면 허용, 1바이트 초과면 .contentTooLarge (재리뷰)
        let store = makeStore()
        let atCap = String(repeating: "a", count: StickyStore.maxContentBytes)
        if case .failure = store.add(content: atCap) { XCTFail("정확히 한도는 허용돼야") }
        let overCap = String(repeating: "a", count: StickyStore.maxContentBytes + 1)
        if case .failure(let e) = store.add(content: overCap) {
            XCTAssertEqual(e, .contentTooLarge)
        } else { XCTFail("한도 초과는 .contentTooLarge") }
    }

    func testAddContentCapCountsBytesNotChars() {
        // 멀티바이트는 문자 수가 아닌 UTF-8 바이트로 판정 (한글 3바이트)
        let store = StickyStore(defaults: defaults, screenFrame: screen)
        // maxContentBytes 바로 아래를 한글로 채워 바이트 기준 판정 확인 (문자수 < 바이트수)
        let charCount = StickyStore.maxContentBytes / 3      // 한글 charCount개 = 3·charCount 바이트 ≤ 한도
        let ok = String(repeating: "가", count: charCount)
        XCTAssertLessThanOrEqual(ok.utf8.count, StickyStore.maxContentBytes)
        if case .failure = store.add(content: ok) { XCTFail("바이트 한도 내 한글은 허용") }
        let over = String(repeating: "가", count: charCount + 1) // 3바이트 더 → 초과
        if case .failure(let e) = store.add(content: over) {
            XCTAssertEqual(e, .contentTooLarge)
        } else { XCTFail("바이트 초과 한글은 .contentTooLarge") }
    }

    func testRestoreDropsOversizeContent() {
        // 예전(큰 캡) 시절 저장된 >1MB 노트는 복원 시 버려져야 (렌더 프리즈 방지, 재리뷰 MAJOR)
        let big = String(repeating: "a", count: StickyStore.maxContentBytes + 100)
        let json = """
        {"schemaVersion":1,"notes":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"\(big)",
           "frame":[[0,0],[100,100]],"opacity":1,"createdAt":0},
          {"id":"22222222-2222-2222-2222-222222222222","content":"ok",
           "frame":[[0,0],[100,100]],"opacity":1,"createdAt":0}
        ]}
        """
        defaults.set(json.data(using: .utf8), forKey: "stickyStore.v1")
        let store = makeStore()
        store.restore()
        XCTAssertEqual(store.notes.count, 1)          // 큰 노트 버려지고 정상 1개만
        XCTAssertEqual(store.notes[0].content, "ok")
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

    func testRestoreReportsDropCounts() {
        // §7: 복원 드롭을 호출부가 사용자에게 알릴 수 있도록 건수를 보고한다.
        // 구성: oversize 2개 + 정상 34개 = 36개 → withinSize 34, cap(30) 초과 4개 잘림 → restored 30.
        let big = String(repeating: "a", count: StickyStore.maxContentBytes + 100)
        var notesJSON: [String] = []
        for i in 0..<2 {
            let uuid = String(format: "%08d-1111-1111-1111-111111111111", i)
            notesJSON.append("{\"id\":\"\(uuid)\",\"content\":\"\(big)\",\"frame\":[[0,0],[100,100]],\"opacity\":1,\"createdAt\":0}")
        }
        for i in 0..<34 {
            let uuid = String(format: "%08d-2222-2222-2222-222222222222", i)
            notesJSON.append("{\"id\":\"\(uuid)\",\"content\":\"n\(i)\",\"frame\":[[0,0],[100,100]],\"opacity\":1,\"createdAt\":0}")
        }
        let json = "{\"schemaVersion\":1,\"notes\":[\(notesJSON.joined(separator: ","))]}"
        defaults.set(json.data(using: .utf8), forKey: "stickyStore.v1")
        let store = makeStore()
        let outcome = store.restore()
        XCTAssertEqual(outcome.droppedOversize, 2)
        XCTAssertEqual(outcome.droppedOverCap, 4)   // withinSize 34 - clamp 30
        XCTAssertEqual(outcome.restored, StickyStore.maxStickies)
        XCTAssertTrue(outcome.hasDrops)
        XCTAssertEqual(store.notes.count, StickyStore.maxStickies)
    }

    func testRestoreCleanStateReportsNoDrops() {
        // 정상 복원(드롭 없음)은 hasDrops == false → 사용자 알림 안 뜸
        let store = makeStore()
        _ = try! store.add(content: "a").get()
        let store2 = makeStore()
        let outcome = store2.restore()
        XCTAssertFalse(outcome.hasDrops)
        XCTAssertEqual(outcome.restored, 1)
        XCTAssertEqual(outcome.droppedOversize, 0)
        XCTAssertEqual(outcome.droppedOverCap, 0)
    }

    func testRestoreCompactsDroppedBlob() {
        // 드롭 후 정규화 결과가 영속화되어, 재복원 시 드롭이 반복되지 않는다 (A-Minor: restore 컴팩션).
        let big = String(repeating: "a", count: StickyStore.maxContentBytes + 100)
        let json = """
        {"schemaVersion":1,"notes":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"\(big)",
           "frame":[[0,0],[100,100]],"opacity":1,"createdAt":0},
          {"id":"22222222-2222-2222-2222-222222222222","content":"ok",
           "frame":[[0,0],[100,100]],"opacity":1,"createdAt":0}
        ]}
        """
        defaults.set(json.data(using: .utf8), forKey: "stickyStore.v1")
        let first = makeStore().restore()
        XCTAssertTrue(first.hasDrops)                 // 첫 복원: 큰 노트 드롭
        let second = makeStore().restore()
        XCTAssertFalse(second.hasDrops)               // 재복원: 이미 컴팩션되어 드롭 없음
        XCTAssertEqual(second.restored, 1)
    }

    func testRemovePersists() {
        let store = makeStore()
        let note = try! store.add(content: "a").get()
        store.remove(id: note.id)
        let store2 = makeStore()
        store2.restore()
        XCTAssertEqual(store2.notes.count, 0)
    }

    func testMigrationV1NoteWithoutPinnedSurvivesFullFidelity() {
        // 핀 필드가 없던 v1 저장본이 새 구조로 디코드될 때 전 필드 왕복 + pinned == nil 생존
        let v1 = """
        {"schemaVersion":1,"notes":[
          {"id":"11111111-1111-1111-1111-111111111111","content":"레거시",
           "frame":[[10,20],[300,200]],"opacity":0.8,"createdAt":0}
        ]}
        """
        defaults.set(v1.data(using: .utf8), forKey: "stickyStore.v1")
        let store = makeStore()
        store.restore()
        XCTAssertEqual(store.notes.count, 1)
        let n = store.notes[0]
        XCTAssertEqual(n.content, "레거시")
        XCTAssertEqual(n.frame, CGRect(x: 10, y: 20, width: 300, height: 200))
        XCTAssertEqual(n.opacity, 0.8)
        XCTAssertNil(n.pinned)
    }
}
