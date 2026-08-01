import Foundation

public enum StickyURLError: Error, Equatable {
    case unknownHost      // scheme != "sticky" / host != "new" / non-empty path / fragment / parse failure (pragmatic collapse)
    case missingContent   // content absent / empty / duplicate
    case invalidEncoding  // content alphabet violation / base64 or UTF-8 decode failure
}

/// sticky:// URL parser (docs/url-scheme-spec.md contract). Pure logic, no AppKit.
/// Note: the raw URL length limit (receiver-side oversize) is decided by the AppDelegate that receives the URL (Task 10), not this parser.
public enum StickyURLParser {
    // content alphabet: base64url (unpadded). \A…\z anchor the whole string. NSRegularExpression's $ allows a trailing \n, so it's banned.
    private static let base64urlAlphabet = try! NSRegularExpression(pattern: "\\A[A-Za-z0-9_-]+\\z")

    public static func parse(_ url: URL) -> Result<String, StickyURLError> {
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failure(.unknownHost)  // collapse a parse failure into unknownHost (observed behavior matches the contract)
        }
        // scheme: lowercase "sticky" only. URLComponents doesn't lowercase custom-scheme host/scheme, so compare explicitly.
        guard comps.scheme == "sticky" else { return .failure(.unknownHost) }
        // host: lowercase "new" only (case-sensitive)
        guard comps.host == "new" else { return .failure(.unknownHost) }
        // path: only empty or "/" (a trailing slash) allowed
        guard comps.path.isEmpty || comps.path == "/" else { return .failure(.unknownHost) }
        // fragment: not allowed
        guard comps.fragment == nil else { return .failure(.unknownHost) }

        // content: exactly 1 (reject duplicate, zero, empty). Check the raw (percent-encoded) value:
        // queryItems.value is already percent-decoded and would miss a bypass like %47 (→G) (contract: "check before decoding").
        let contentItems = (comps.percentEncodedQueryItems ?? []).filter { $0.name == "content" }
        guard contentItems.count == 1,
              let raw = contentItems[0].value, !raw.isEmpty else {
            return .failure(.missingContent)
        }

        // alphabet check (unpadded base64url): a % or newline in raw is rejected here
        let range = NSRange(raw.startIndex..., in: raw)
        guard base64urlAlphabet.firstMatch(in: raw, range: range) != nil else {
            return .failure(.invalidEncoding)
        }

        // base64url → standard base64: reverse-map and re-pad (skip it and even valid input goes nil)
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
