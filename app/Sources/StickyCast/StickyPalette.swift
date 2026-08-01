import SwiftUI

/// Sticky-note preset color palette. Persisted as the rawValue key (String); the actual Color mapping lives here (app side).
/// StickyNote.color holds this key; nil means the default background (windowBackgroundColor).
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

    /// Stored key → background Color. If nil or an unsupported key (e.g. a color from a future version), fall back to nil = default background.
    static func color(forKey key: String?) -> Color? {
        guard let key, let palette = StickyPalette(rawValue: key) else { return nil }
        return palette.color
    }
}
