import XCTest
@testable import StickyCastCore

/// 크로스-컴포넌트 왕복: 확장 인코더가 기계 생성한 fixtures/roundtrip.json을 그대로 읽어,
/// 실제 앱 파서가 각 encoded를 원문 input으로 복원하는지 검증한다.
/// 확장 측 대응 테스트: extension/test/crosscomponent.test.ts (같은 파일을 인코더로 검증).
/// → 두 컴포넌트가 하나의 기계 생성 소스를 공유하므로 "손으로 친 같은 오답 벡터"를 함께 통과하는 리스크가 사라진다.
final class CrossComponentTests: XCTestCase {
    private struct Fixture: Decodable { let input: String; let encoded: String; let note: String? }
    private struct Root: Decodable { let fixtures: [Fixture] }

    private func loadFixtures() throws -> [Fixture] {
        // 소스 파일 위치 기준으로 리포 루트의 공용 픽스처를 찾음 (cwd/빌드 디렉터리 무관).
        // .../app/Tests/StickyCastTests/CrossComponentTests.swift → 4단계 상위 = 리포 루트
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 { root.deleteLastPathComponent() }
        let url = root.appendingPathComponent("fixtures/roundtrip.json")
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Root.self, from: data).fixtures
    }

    func testFixturesRoundTripThroughParser() throws {
        let fixtures = try loadFixtures()
        XCTAssertFalse(fixtures.isEmpty, "픽스처 로드 실패/빈 배열 — 경로 회귀 가드")

        for fx in fixtures {
            let url = try XCTUnwrap(
                URL(string: "sticky://new?content=\(fx.encoded)"),
                "URL 생성 실패: \(fx.encoded)")
            let result = StickyURLParser.parse(url)
            XCTAssertEqual(
                result, .success(fx.input),
                "파서가 원문을 복원하지 못함 (\(fx.note ?? fx.input)) — encoded=\(fx.encoded)")
        }
    }
}
