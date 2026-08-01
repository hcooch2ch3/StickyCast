import XCTest
@testable import StickyCastCore

/// Regression: discard out-of-order completions of async file reads with latest-wins,
/// so a sticker cannot get stuck lagging behind the file.
final class ReadGenerationTests: XCTestCase {
    func testStaleGenerationIsDroppedLatestWins() {
        let g = ReadGeneration()
        let id = UUID()
        let t1 = g.begin(id)   // read 1 starts
        let t2 = g.begin(id)   // read 2 starts (newer); assume read 2 completes first
        XCTAssertTrue(g.isCurrent(id, t2), "최신 읽기2 완료는 반영")
        XCTAssertFalse(g.isCurrent(id, t1), "뒤늦게 도착한 읽기1 완료는 폐기(stale 고착 방지)")
    }

    func testMonotonicAcrossRounds() {
        let g = ReadGeneration()
        let id = UUID()
        _ = g.begin(id)
        let t2 = g.begin(id)
        XCTAssertTrue(g.isCurrent(id, t2))
        let t3 = g.begin(id)          // next round
        XCTAssertFalse(g.isCurrent(id, t2), "직전 세대는 새 읽기 시작으로 무효")
        XCTAssertTrue(g.isCurrent(id, t3))
    }

    func testPerNoteIndependence() {
        let g = ReadGeneration()
        let a = UUID(); let b = UUID()
        let ta = g.begin(a)
        _ = g.begin(b)                // b's read must not affect a
        XCTAssertTrue(g.isCurrent(a, ta), "다른 노트의 읽기가 이 노트 세대를 건드리면 안 됨")
    }

    func testUnknownTokenNotCurrent() {
        let g = ReadGeneration()
        XCTAssertFalse(g.isCurrent(UUID(), 1), "begin 없은 노트는 어떤 토큰도 최신 아님")
    }
}
