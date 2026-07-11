import Foundation

public enum StickyURLError: Error, Equatable {
    case unknownHost      // scheme != "sticky" / host != "new" / 비어있지 않은 path / fragment / 파싱 실패(실용적 축약)
    case missingContent   // content 없음 / 빈 값 / 중복
    case invalidEncoding  // content 알파벳 위반 / base64·UTF-8 디코드 실패
}

/// sticky:// URL 파서 (docs/url-scheme-spec.md 계약). 순수 로직 — AppKit 무관.
/// 참고: URL 원문 길이 한도(수신측 oversize)는 이 파서가 아니라 URL을 받는 AppDelegate(Task 10)가 판정한다.
public enum StickyURLParser {
    // content 알파벳: base64url (무패딩). \A…\z로 전체 문자열 앵커 — NSRegularExpression의 $는 trailing \n을 허용하므로 금지.
    private static let base64urlAlphabet = try! NSRegularExpression(pattern: "\\A[A-Za-z0-9_-]+\\z")

    public static func parse(_ url: URL) -> Result<String, StickyURLError> {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.unknownHost)  // 파싱 실패를 unknownHost로 축약 (관찰 동작은 계약 일치)
        }
        // scheme: 소문자 "sticky"만. URLComponents는 커스텀 스킴 host/scheme를 소문자화하지 않으므로 명시 비교.
        guard comps.scheme == "sticky" else { return .failure(.unknownHost) }
        // host: 소문자 "new"만 (대소문자 구분)
        guard comps.host == "new" else { return .failure(.unknownHost) }
        // path: 비어 있거나 "/"(트레일링 슬래시)만 허용
        guard comps.path.isEmpty || comps.path == "/" else { return .failure(.unknownHost) }
        // fragment: 금지
        guard comps.fragment == nil else { return .failure(.unknownHost) }

        // content: 정확히 1개 (중복·0개·빈 값 거부). raw(percent-encoded) 값으로 검사 —
        // queryItems.value는 이미 percent-decode되어 %47(→G) 같은 우회를 놓친다 (계약: "디코드 전 검사").
        let contentItems = (comps.percentEncodedQueryItems ?? []).filter { $0.name == "content" }
        guard contentItems.count == 1,
              let raw = contentItems[0].value, !raw.isEmpty else {
            return .failure(.missingContent)
        }

        // 알파벳 검사 (base64url 무패딩) — raw에 %·개행 등이 있으면 여기서 거부
        let range = NSRange(raw.startIndex..., in: raw)
        guard base64urlAlphabet.firstMatch(in: raw, range: range) != nil else {
            return .failure(.invalidEncoding)
        }

        // base64url → 표준 base64: 역변환 + 재패딩 (생략 시 정상 입력도 nil)
        var b64 = raw.replacingOccurrences(of: "-", with: "+")
                     .replacingOccurrences(of: "_", with: "/")
        let remainder = b64.count % 4
        if remainder > 0 { b64 += String(repeating: "=", count: 4 - remainder) }

        guard let data = Data(base64Encoded: b64),
              let content = String(data: data, encoding: .utf8),
              !content.isEmpty else {
            return .failure(.invalidEncoding)
        }
        return .success(content)
    }
}
