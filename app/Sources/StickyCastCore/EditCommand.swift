import Foundation

/// A standard text-editing command reachable by its ⌘ shortcut.
public enum EditCommand: String, CaseIterable, Sendable {
    case undo, redo, cut, copy, paste, selectAll
}

/// Pure key→command matching, kept out of AppKit so it can be tested directly.
///
/// Exact-modifier matching matters: ⌘C means copy, but ⌥⌘C or ⌃⌘C are different shortcuts a text
/// view (or another app) may define, and swallowing them here would break them silently.
public enum EditShortcut {
    public static func command(key: String, command: Bool, shift: Bool = false,
                               option: Bool = false, control: Bool = false) -> EditCommand? {
        guard command, !option, !control else { return nil }
        switch key.lowercased() {
        case "z": return shift ? .redo : .undo
        case "x": return shift ? nil : .cut
        case "c": return shift ? nil : .copy
        case "v": return shift ? nil : .paste
        case "a": return shift ? nil : .selectAll
        default:  return nil
        }
    }
}
