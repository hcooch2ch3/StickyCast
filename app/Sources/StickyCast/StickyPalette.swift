import SwiftUI

/// 포스트잇 프리셋 색상 팔레트. 저장은 rawValue 키(String), 실제 Color 매핑은 여기(앱 측).
/// StickyNote.color는 이 키를 담고, nil = 기본 배경(windowBackgroundColor).
enum StickyPalette: String, CaseIterable, Identifiable {
    case yellow, pink, blue, green, purple

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return Color(red: 1.00, green: 0.98, blue: 0.77)
        case .pink:   return Color(red: 0.97, green: 0.73, blue: 0.82)
        case .blue:   return Color(red: 0.70, green: 0.90, blue: 0.99)
        case .green:  return Color(red: 0.78, green: 0.90, blue: 0.79)
        case .purple: return Color(red: 0.88, green: 0.75, blue: 0.91)
        }
    }

    var label: String {
        switch self {
        case .yellow: return "노랑"
        case .pink:   return "분홍"
        case .blue:   return "파랑"
        case .green:  return "초록"
        case .purple: return "보라"
        }
    }

    /// 저장된 키 → 배경 Color. nil이거나 미지원 키(예: 미래 버전 색)면 nil = 기본 배경으로 폴백.
    static func color(forKey key: String?) -> Color? {
        guard let key, let palette = StickyPalette(rawValue: key) else { return nil }
        return palette.color
    }
}
