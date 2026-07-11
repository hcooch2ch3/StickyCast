import XCTest
@testable import StickyCastCore

final class StickyURLParserTests: XCTestCase {
    // 공용 골든 벡터 (docs/url-scheme-spec.md) — 3종 전부
    func testGoldenVector_KoreanEmoji() {
        let url = URL(string: "sticky://new?content=7JWI64WV8J-OiQ")!
        XCTAssertEqual(StickyURLParser.parse(url), .success("안녕🎉"))
    }
    func testGoldenVector_ASCII() {
        let url = URL(string: "sticky://new?content=aGk")!
        XCTAssertEqual(StickyURLParser.parse(url), .success("hi"))
    }
    func testGoldenVector_Underscore() {
        // 읽기??? — '_' 포함 (가장 취약한 _→/ 역변환 경로)
        let url = URL(string: "sticky://new?content=7J296riwPz8_")!
        XCTAssertEqual(StickyURLParser.parse(url), .success("읽기???"))
    }

    // host / path / fragment 문법
    func testUnknownHost() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://update?content=aGk")!), .failure(.unknownHost))
    }
    func testUppercaseHostRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://NEW?content=aGk")!), .failure(.unknownHost))
    }
    func testNonEmptyPathRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new/foo?content=aGk")!), .failure(.unknownHost))
    }
    func testTrailingSlashAllowed() {
        // 빈 path로 간주하여 허용
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new/?content=aGk")!), .success("hi"))
    }
    func testFragmentRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk#x")!), .failure(.unknownHost))
    }

    // content 유무 / 빈 값 / 중복
    func testMissingContent() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new")!), .failure(.missingContent))
    }
    func testEmptyContent() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=")!), .failure(.missingContent))
    }
    func testDuplicateContentRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk&content=YWI")!), .failure(.missingContent))
    }

    // scheme (iter-007 회귀)
    func testNonStickySchemeRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "http://new?content=aGk")!), .failure(.unknownHost))
        XCTAssertEqual(StickyURLParser.parse(URL(string: "evil://new?content=aGk")!), .failure(.unknownHost))
    }

    // content 알파벳 / 디코드
    func testPercentEncodedContentRejected() {
        // a%47k: raw에 % 포함. URLComponents가 %47→G로 디코드해 aGk가 되지만, raw 검사로 거부해야 함 (계약: 디코드 전 검사)
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=a%47k")!), .failure(.invalidEncoding))
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=%61Gk")!), .failure(.invalidEncoding))
    }
    func testTrailingNewlineRejected() {
        // aGk%0A → raw "aGk%0A": \A…\z 앵커가 개행 percent-escape를 거부
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk%0A")!), .failure(.invalidEncoding))
    }
    func testAlphabetViolation() {
        // %25%25%25 → "%%%" (base64url 알파벳 아님)
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=%25%25%25")!), .failure(.invalidEncoding))
    }
    func testInvalidUTF8Bytes() {
        // 0xFF 0xFE = 유효 base64url이지만 UTF-8로 디코드 불가 → "__4" (Data [0xFF,0xFE])
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=__4")!), .failure(.invalidEncoding))
    }

    // 전방 호환
    func testUnknownParamsIgnored() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk&future=x")!), .success("hi"))
    }
}
