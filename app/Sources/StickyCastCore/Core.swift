// StickyCastCore — 타깃 앵커 (Task 7·8이 실코드 추가)

import Foundation

/// 내보내기 파일명 생성 — 순수 로직이라 단위 테스트 대상. AppKit(NSSavePanel) 밖에 둔다.
public enum ExportNaming {
    /// 스티커 본문에서 안전한 .md 파일명을 만든다.
    /// - 첫 줄을 제목으로 삼되 선행 `#`·공백을 제거
    /// - 파일명 부적합 문자(`/ : \ ? % * | " < >`)는 `-`로 치환
    /// - 40자로 절단, 비면 "sticker"
    public static func filename(for content: String) -> String {
        let firstLine = content.split(separator: "\n", omittingEmptySubsequences: false)
            .first.map(String.init) ?? ""
        let stripped = firstLine.drop(while: { $0 == "#" || $0 == " " })
        let base = String(stripped).trimmingCharacters(in: .whitespaces)
        let illegal = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let safe = base.components(separatedBy: illegal).joined(separator: "-")
        let clipped = String(safe.prefix(40)).trimmingCharacters(in: .whitespaces)
        return clipped.isEmpty ? "sticker.md" : "\(clipped).md"
    }
}
