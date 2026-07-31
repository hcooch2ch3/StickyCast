import XCTest
@testable import StickyCastCore

/// Finding #2 회귀: 비동기 파일 읽기의 out-of-order 완료를 latest-wins로 폐기해
/// 스티커가 파일보다 뒤처져 고착되는 것을 막는다.
final class ReadGenerationTests: XCTestCase {
    func testStaleGenerationIsDroppedLatestWins() {
        let g = ReadGeneration()
        let id = UUID()
        let t1 = g.begin(id)   // 읽기1 시작
        let t2 = g.begin(id)   // 읽기2 시작(더 최신) — 읽기2가 먼저 완료했다고 가정
        XCTAssertTrue(g.isCurrent(id, t2), "최신 읽기2 완료는 반영")
        XCTAssertFalse(g.isCurrent(id, t1), "뒤늦게 도착한 읽기1 완료는 폐기(stale 고착 방지)")
    }

    func testMonotonicAcrossRounds() {
        let g = ReadGeneration()
        let id = UUID()
        _ = g.begin(id)
        let t2 = g.begin(id)
        XCTAssertTrue(g.isCurrent(id, t2))
        let t3 = g.begin(id)          // 다음 라운드
        XCTAssertFalse(g.isCurrent(id, t2), "직전 세대는 새 읽기 시작으로 무효")
        XCTAssertTrue(g.isCurrent(id, t3))
    }

    func testPerNoteIndependence() {
        let g = ReadGeneration()
        let a = UUID(); let b = UUID()
        let ta = g.begin(a)
        _ = g.begin(b)                // b의 읽기는 a에 영향 없어야
        XCTAssertTrue(g.isCurrent(a, ta), "다른 노트의 읽기가 이 노트 세대를 건드리면 안 됨")
    }

    func testUnknownTokenNotCurrent() {
        let g = ReadGeneration()
        XCTAssertFalse(g.isCurrent(UUID(), 1), "begin 없은 노트는 어떤 토큰도 최신 아님")
    }
}
