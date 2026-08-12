import AppKit
import StickyCastCore

/// The standard text-editing commands: the Edit menu that carries them, and the dispatch that
/// actually fires them inside a sticker.
///
/// Why this exists: StickyCast is an `LSUIElement` agent app whose stickers are nonactivating
/// panels, so it never had a main menu at all — leaving AppKit nowhere to match ⌘X / ⌘C / ⌘V / ⌘A.
/// Typing into a sticker worked; cut, copy, paste and select-all did nothing.
///
/// Installing the menu alone is not enough. Menu key equivalents are dispatched to the **key
/// window's** responder chain, and a sticker panel is deliberately nonactivating, so that lookup is
/// not something to rely on here. Measured on this app: the Edit menu does match the event
/// (`performKeyEquivalent` → true) but the panel's own chain never sees it. So the panel intercepts
/// the shortcut itself (`StickyPanel.performKeyEquivalent`) and hands it to its own first responder,
/// which works whether or not the app is active. The menu stays because it is the standard surface
/// for these commands and it covers the app's other AppKit UI (alerts, open panels).
enum EditMenu {
    /// One row per command: the same table builds the menu and resolves an intercepted shortcut, so
    /// the two can't drift apart.
    private struct Row {
        let command: EditCommand
        let title: () -> String     // resolved at build time so a language switch retitles the menu
        let key: String
        let action: Selector
    }

    private static let rows: [Row] = [
        Row(command: .undo, title: { L10n.undo() }, key: "z", action: Selector(("undo:"))),
        Row(command: .redo, title: { L10n.redo() }, key: "z", action: Selector(("redo:"))),
        Row(command: .cut, title: { L10n.cut() }, key: "x", action: #selector(NSText.cut(_:))),
        Row(command: .copy, title: { L10n.copy() }, key: "c", action: #selector(NSText.copy(_:))),
        Row(command: .paste, title: { L10n.paste() }, key: "v", action: #selector(NSText.paste(_:))),
        Row(command: .selectAll, title: { L10n.selectAll() }, key: "a", action: #selector(NSText.selectAll(_:))),
    ]

    private static func action(for command: EditCommand) -> Selector? {
        rows.first { $0.command == command }?.action
    }

    // MARK: Menu

    /// Build the main menu. AppKit always treats the first submenu as the application menu, so a
    /// placeholder app item comes first and the Edit menu second.
    static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appItem = NSMenuItem()
        appItem.submenu = NSMenu(title: "StickyCast")
        main.addItem(appItem)

        let editItem = NSMenuItem()
        editItem.submenu = makeEditMenu()
        main.addItem(editItem)

        return main
    }

    static func makeEditMenu() -> NSMenu {
        let menu = NSMenu(title: L10n.edit())
        for row in rows {
            if row.command == .cut { menu.addItem(.separator()) }   // undo/redo above, clipboard below
            let item = menu.addItem(withTitle: row.title(), action: row.action, keyEquivalent: row.key)
            if row.command == .redo { item.keyEquivalentModifierMask = [.command, .shift] }
        }
        return menu
    }

    // MARK: Dispatch

    /// Resolve a key event to an edit command and run it against `window`'s own responder chain.
    /// Returns false for anything unrecognized so the event falls through untouched.
    static func dispatch(_ event: NSEvent, in window: NSWindow) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let key = event.charactersIgnoringModifiers,
              let command = EditShortcut.command(key: key,
                                                 command: flags.contains(.command),
                                                 shift: flags.contains(.shift),
                                                 option: flags.contains(.option),
                                                 control: flags.contains(.control)),
              let action = action(for: command),
              let responder = window.firstResponder
        else { return false }
        // tryToPerform walks the chain from this window's own first responder — unlike sendAction(to: nil),
        // which starts at the KEY window and would find nothing while another app holds focus.
        return responder.tryToPerform(action, with: nil)
    }
}
