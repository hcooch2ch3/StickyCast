import Foundation

/// A standard text-editing command reachable by its ⌘ shortcut.
public enum EditCommand: String, CaseIterable, Sendable {
    case undo, redo, cut, copy, paste, selectAll

    /// The commands a window may safely claim by walking its own responder chain.
    ///
    /// `tryToPerform` stops at the first responder that merely *responds to* the selector, which is
    /// not the same as one that can meaningfully act. The chain out of a text view ends at the
    /// window, and `NSWindow` responds to `undo:`/`redo:` (it forwards to its own undo manager) —
    /// so claiming those would swallow ⌘Z / ⇧⌘Z unconditionally, in read mode and with nothing to
    /// undo, and block the menu from routing them. `NSWindow` responds to none of the four below,
    /// so an unhandled ⌘C falls through untouched. Verified against AppKit: NSWindow responds
    /// undo:/redo: true, cut:/copy:/paste:/selectAll: false; NSTextView is the mirror image.
    public static let windowDispatchable: [EditCommand] = [.cut, .copy, .paste, .selectAll]

    /// The Objective-C selector this command sends. Lives here, away from AppKit, so a missing or
    /// malformed entry is caught by a test rather than dead-ending silently at runtime.
    public var selectorName: String {
        switch self {
        case .undo: return "undo:"
        case .redo: return "redo:"
        case .cut: return "cut:"
        case .copy: return "copy:"
        case .paste: return "paste:"
        case .selectAll: return "selectAll:"
        }
    }

    /// Virtual key code for this command's letter on a US layout. Key codes are positional, so they
    /// identify the physical key regardless of what character the active layout produces — the
    /// fallback that keeps ⌘C working on a Cyrillic or Greek layout, where the reported character
    /// is "с" and no letter match is possible.
    public var keyCode: UInt16 {
        switch self {
        case .undo, .redo: return 6    // Z
        case .cut: return 7            // X
        case .copy: return 8           // C
        case .paste: return 9          // V
        case .selectAll: return 0      // A
        }
    }
}

/// Pure key→command matching, kept out of AppKit so it can be tested directly.
///
/// Exact-modifier matching matters: ⌘C means copy, but ⌥⌘C or ⌃⌘C are different shortcuts a text
/// view (or another app) may define, and swallowing them here would break them silently.
public enum EditShortcut {
    /// `key` is the event's characters-ignoring-modifiers; `keyCode` its virtual key code. The
    /// letter is tried first (it follows a remapped layout such as Dvorak, where the key code
    /// would point at the wrong command) and the key code serves as the fallback for layouts that
    /// produce no Latin letter at all.
    public static func command(key: String, keyCode: UInt16? = nil, command: Bool,
                               shift: Bool = false, option: Bool = false,
                               control: Bool = false) -> EditCommand? {
        guard command, !option, !control else { return nil }
        if let byLetter = byLetter(key.lowercased(), shift: shift) { return byLetter }
        guard let keyCode else { return nil }
        return EditCommand.allCases.first { $0.keyCode == keyCode && matchesShift($0, shift: shift) }
    }

    private static func byLetter(_ key: String, shift: Bool) -> EditCommand? {
        switch key {
        case "z": return shift ? .redo : .undo
        case "x": return shift ? nil : .cut
        case "c": return shift ? nil : .copy
        case "v": return shift ? nil : .paste
        case "a": return shift ? nil : .selectAll
        default:  return nil
        }
    }

    /// Shift distinguishes undo from redo and is otherwise disqualifying.
    private static func matchesShift(_ command: EditCommand, shift: Bool) -> Bool {
        switch command {
        case .undo: return !shift
        case .redo: return shift
        default:    return !shift
        }
    }
}
