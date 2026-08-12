import AppKit
import StickyCastCore

/// The standard text-editing commands: the Edit menu that carries them, and the dispatch that
/// actually fires them inside a sticker.
///
/// Why this exists: StickyCast is an `LSUIElement` agent app whose stickers are nonactivating
/// panels, so it never had a main menu at all — leaving AppKit nowhere to match ⌘X / ⌘C / ⌘V / ⌘A.
/// Typing into a sticker worked; cut, copy, paste and select-all did nothing.
///
/// The menu is justified on its own: it gives the app's other AppKit UI (the filename field in the
/// open/save panels, alerts) the Edit commands it never had.
///
/// Whether the menu ALONE would also fix the stickers is **unresolved**. Menu key equivalents are
/// resolved against the **key window's** responder chain, and a sticker panel is deliberately
/// nonactivating — but `becomesKeyOnlyIfNeeded` is exactly what makes a click into the text view
/// hand the panel key status, so it may well be key at the moment the user types. That state could
/// not be reproduced in-process (an LSUIElement app cannot activate itself, and programmatic
/// `makeKey` is a no-op under `becomesKeyOnlyIfNeeded`), so it was never measured either way;
/// settling it needs one real keypress with a log inside `performKeyEquivalent`.
///
/// So `StickyPanel.performKeyEquivalent` also resolves the shortcut itself and hands it to its own
/// first responder, which works regardless. Dispatch is deliberately limited to the commands a
/// window cannot falsely claim — see `EditCommand.windowDispatchable`.
enum EditMenu {
    /// One row per command — `EditCommand.allCases` order, so a new case that is never given a title
    /// here fails the assertion below rather than silently vanishing from the menu.
    private struct Row {
        let command: EditCommand
        let title: () -> String     // resolved at build time so a language switch retitles the menu
        let key: String
    }

    private static let rows: [Row] = [
        Row(command: .undo, title: { L10n.undo() }, key: "z"),
        Row(command: .redo, title: { L10n.redo() }, key: "z"),
        Row(command: .cut, title: { L10n.cut() }, key: "x"),
        Row(command: .copy, title: { L10n.copy() }, key: "c"),
        Row(command: .paste, title: { L10n.paste() }, key: "v"),
        Row(command: .selectAll, title: { L10n.selectAll() }, key: "a"),
    ]

    /// Selectors come from Core's table, which is unit-tested for completeness. The four clipboard
    /// ones also exist as compile-checked `#selector`s, so this cross-check catches a typo in a
    /// string that would otherwise dead-end silently at runtime.
    private static func action(for command: EditCommand) -> Selector {
        let selector = Selector((command.selectorName))
        assert({
            let compileChecked: [EditCommand: Selector] = [
                .cut: #selector(NSText.cut(_:)), .copy: #selector(NSText.copy(_:)),
                .paste: #selector(NSText.paste(_:)), .selectAll: #selector(NSText.selectAll(_:)),
            ]
            return compileChecked[command].map { $0 == selector } ?? true
        }(), "EditCommand.\(command).selectorName does not match its #selector")
        return selector
    }

    // MARK: Menu

    /// Build the main menu. AppKit always treats the first submenu as the application menu, so a
    /// placeholder app item comes first and the Edit menu second.
    static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        // The app submenu stays empty: an accessory (LSUIElement) app shows no menu bar even while
        // active, so there is nothing here for a user to see. Key equivalents still match without
        // one. The app's own commands live in the status menu, which is the surface people use.
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu(title: "StickyCast")   // app name, untranslated by convention
        main.addItem(appItem)

        let editItem = NSMenuItem()
        editItem.submenu = makeEditMenu()
        main.addItem(editItem)

        return main
    }

    static func makeEditMenu() -> NSMenu {
        assert(rows.map(\.command) == EditCommand.allCases, "every EditCommand needs a menu row")
        let menu = NSMenu(title: L10n.edit())
        for row in rows {
            if row.command == .cut { menu.addItem(.separator()) }   // undo/redo above, clipboard below
            let item = menu.addItem(withTitle: row.title(), action: action(for: row.command),
                                    keyEquivalent: row.key)
            if row.command == .redo { item.keyEquivalentModifierMask = [.command, .shift] }
        }
        return menu
    }

    // MARK: Dispatch

    /// Resolve a key event to an edit command and run it against `window`'s own responder chain.
    /// Returns false for anything unrecognized so the event falls through untouched.
    static func dispatch(_ event: NSEvent, in window: NSWindow) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let command = EditShortcut.command(key: event.charactersIgnoringModifiers ?? "",
                                                 keyCode: event.keyCode,
                                                 command: flags.contains(.command),
                                                 shift: flags.contains(.shift),
                                                 option: flags.contains(.option),
                                                 control: flags.contains(.control)),
              EditCommand.windowDispatchable.contains(command),   // see the note on that list
              let responder = window.firstResponder
        else { return false }
        // tryToPerform walks the chain from this window's own first responder — unlike sendAction(to: nil),
        // which starts at the KEY window and would find nothing while another app holds focus.
        return responder.tryToPerform(action(for: command), with: nil)
    }
}
