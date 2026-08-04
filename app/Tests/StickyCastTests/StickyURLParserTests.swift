import XCTest
@testable import StickyCastCore

final class StickyURLParserTests: XCTestCase {
    // Shared golden vectors, all 3
    func testGoldenVector_KoreanEmoji() {
        let url = URL(string: "sticky://new?content=7JWI64WV8J-OiQ")!
        XCTAssertEqual(StickyURLParser.parse(url), .success("안녕🎉"))
    }
    func testGoldenVector_ASCII() {
        let url = URL(string: "sticky://new?content=aGk")!
        XCTAssertEqual(StickyURLParser.parse(url), .success("hi"))
    }
    func testGoldenVector_Underscore() {
        // this vector contains '_' (the most fragile _→/ reverse-mapping path)
        let url = URL(string: "sticky://new?content=7J296riwPz8_")!
        XCTAssertEqual(StickyURLParser.parse(url), .success("읽기???"))
    }

    // host / path / fragment grammar
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
        // treated as an empty path, so allowed
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new/?content=aGk")!), .success("hi"))
    }
    func testFragmentRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk#x")!), .failure(.unknownHost))
    }

    // content presence / empty value / duplicate
    func testMissingContent() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new")!), .failure(.missingContent))
    }
    func testEmptyContent() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=")!), .failure(.missingContent))
    }
    func testDuplicateContentRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk&content=YWI")!), .failure(.missingContent))
    }

    // scheme regression
    func testNonStickySchemeRejected() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "http://new?content=aGk")!), .failure(.unknownHost))
        XCTAssertEqual(StickyURLParser.parse(URL(string: "evil://new?content=aGk")!), .failure(.unknownHost))
    }

    // content alphabet / decode
    func testPercentEncodedContentRejected() {
        // a%47k: raw contains %. URLComponents decodes %47→G to yield aGk, but the raw check must reject it (contract: check before decoding)
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=a%47k")!), .failure(.invalidEncoding))
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=%61Gk")!), .failure(.invalidEncoding))
    }
    func testTrailingNewlineRejected() {
        // aGk%0A → raw "aGk%0A": the \A...\z anchors reject the newline percent-escape
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk%0A")!), .failure(.invalidEncoding))
    }
    func testAlphabetViolation() {
        // %25%25%25 → "%%%" (not the base64url alphabet)
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=%25%25%25")!), .failure(.invalidEncoding))
    }
    func testInvalidUTF8Bytes() {
        // 0xFF 0xFE = valid base64url but not decodable as UTF-8 → "__4" (Data [0xFF,0xFE])
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=__4")!), .failure(.invalidEncoding))
    }

    // forward compatibility
    func testUnknownParamsIgnored() {
        XCTAssertEqual(StickyURLParser.parse(URL(string: "sticky://new?content=aGk&future=x")!), .success("hi"))
    }
}
