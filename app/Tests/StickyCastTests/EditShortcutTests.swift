import XCTest
@testable import StickyCastCore

final class EditShortcutTests: XCTestCase {
    func testClipboardShortcuts() {
        XCTAssertEqual(EditShortcut.command(key: "x", command: true), .cut)
        XCTAssertEqual(EditShortcut.command(key: "c", command: true), .copy)
        XCTAssertEqual(EditShortcut.command(key: "v", command: true), .paste)
        XCTAssertEqual(EditShortcut.command(key: "a", command: true), .selectAll)
    }

    func testUndoAndRedoDifferOnlyByShift() {
        XCTAssertEqual(EditShortcut.command(key: "z", command: true), .undo)
        XCTAssertEqual(EditShortcut.command(key: "z", command: true, shift: true), .redo)
    }

    /// charactersIgnoringModifiers reports an uppercase letter when shift is held.
    func testUppercaseKeyMatches() {
        XCTAssertEqual(EditShortcut.command(key: "Z", command: true, shift: true), .redo)
        XCTAssertEqual(EditShortcut.command(key: "A", command: true), .selectAll)
    }

    func testWithoutCommandNothingMatches() {
        for key in ["x", "c", "v", "a", "z"] {
            XCTAssertNil(EditShortcut.command(key: key, command: false), "bare \(key) must not match")
        }
    }

    /// Swallowing ⌥⌘C or ⌃⌘C would silently break whatever else binds them.
    func testExtraModifiersDoNotMatch() {
        XCTAssertNil(EditShortcut.command(key: "c", command: true, option: true))
        XCTAssertNil(EditShortcut.command(key: "c", command: true, control: true))
        XCTAssertNil(EditShortcut.command(key: "v", command: true, shift: true))
        XCTAssertNil(EditShortcut.command(key: "a", command: true, shift: true))
        XCTAssertNil(EditShortcut.command(key: "z", command: true, shift: true, option: true))
    }

    func testUnrelatedKeysDoNotMatch() {
        XCTAssertNil(EditShortcut.command(key: "q", command: true))
        XCTAssertNil(EditShortcut.command(key: "", command: true))
        XCTAssertNil(EditShortcut.command(key: "\r", command: true))   // ⌘Return stays the save shortcut
    }
}
