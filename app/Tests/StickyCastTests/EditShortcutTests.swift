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
        XCTAssertNil(EditShortcut.command(key: "c", command: true, shift: true))
        XCTAssertNil(EditShortcut.command(key: "x", command: true, shift: true))
        XCTAssertNil(EditShortcut.command(key: "z", command: true, shift: true, option: true))
    }

    /// On a Cyrillic or Greek layout ⌘C reports "с", so the letter can't match. The key code is
    /// positional and still identifies the physical key.
    func testNonLatinLayoutFallsBackToKeyCode() {
        XCTAssertEqual(EditShortcut.command(key: "с", keyCode: 8, command: true), .copy)
        XCTAssertEqual(EditShortcut.command(key: "ф", keyCode: 0, command: true), .selectAll)
        XCTAssertEqual(EditShortcut.command(key: "я", keyCode: 6, command: true), .undo)
        XCTAssertEqual(EditShortcut.command(key: "я", keyCode: 6, command: true, shift: true), .redo)
        XCTAssertNil(EditShortcut.command(key: "й", keyCode: 12, command: true))
        XCTAssertNil(EditShortcut.command(key: "с", keyCode: 8, command: true, option: true))
        XCTAssertNil(EditShortcut.command(key: "с", keyCode: 8, command: true, shift: true))
    }

    /// The letter wins over the key code, so a remapped layout (Dvorak) sends the command its
    /// labelled key promises rather than the one in the US position.
    func testLetterWinsOverKeyCode() {
        XCTAssertEqual(EditShortcut.command(key: "c", keyCode: 9, command: true), .copy)
    }

    /// A Latin letter that maps to no command must NOT fall back to position. On AZERTY the key at
    /// the US-A position reports "q", so a positional fallback would turn ⌘Q into select-all;
    /// QWERTZ ⌘Y would become undo and Dvorak ⌘J would become copy.
    func testRearrangedLatinLayoutsDoNotFallBackToKeyCode() {
        XCTAssertNil(EditShortcut.command(key: "q", keyCode: 0, command: true))   // AZERTY ⌘Q
        XCTAssertNil(EditShortcut.command(key: "y", keyCode: 6, command: true))   // QWERTZ ⌘Y
        XCTAssertNil(EditShortcut.command(key: "j", keyCode: 8, command: true))   // Dvorak ⌘J
        XCTAssertNil(EditShortcut.command(key: "w", keyCode: 6, command: true))   // AZERTY ⌘W
    }

    func testEverySelectorNameIsWellFormed() {
        for command in EditCommand.allCases {
            XCTAssertTrue(command.selectorName.hasSuffix(":"), "\(command) selector needs an argument")
            XCTAssertFalse(command.selectorName.dropLast().isEmpty, "\(command) selector is empty")
        }
        XCTAssertEqual(EditCommand.selectAll.selectorName, "selectAll:")
        XCTAssertEqual(Set(EditCommand.allCases.map(\.selectorName)).count, EditCommand.allCases.count)
    }

    /// A window responds to undo:/redo: (it forwards to its own undo manager), so a panel that
    /// claimed them via tryToPerform would swallow ⌘Z / ⇧⌘Z unconditionally — in read mode, and
    /// with nothing to undo — and block the menu from routing them. It responds to none of the
    /// other four, so those fall through untouched when nothing handles them.
    func testWindowDispatchableExcludesUndoAndRedo() {
        XCTAssertEqual(EditCommand.windowDispatchable, [.cut, .copy, .paste, .selectAll])
        XCTAssertFalse(EditCommand.windowDispatchable.contains(.undo))
        XCTAssertFalse(EditCommand.windowDispatchable.contains(.redo))
    }

    func testUnrelatedKeysDoNotMatch() {
        XCTAssertNil(EditShortcut.command(key: "q", command: true))
        XCTAssertNil(EditShortcut.command(key: "", command: true))
        XCTAssertNil(EditShortcut.command(key: "\r", command: true))   // ⌘Return stays the save shortcut
    }
}
