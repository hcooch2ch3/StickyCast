import AppKit

final class StickyPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = false   // unpinned by default. applyPinned re-adjusts on pin toggle.
        level = .normal           // default: unpinned (sits under the active app so it doesn't block the screen). On pin, applyPinned sets .floating.
        // keep collectionBehavior (canJoinAllSpaces): Phase 1 keeps following every Space.
        // removing it regresses to off-Space notes being unreachable in a nonactivating app (plan option A). Space scoping is Phase 2 (hub).
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true   // drag the body to move
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // core of a cross-app sticker: it must not hide when another app activates. The NSPanel default
        // varies by config, so pin it explicitly (leaving it unset risks defeating always-visible).
        hidesOnDeactivate = false
        // settled (2026-07-12 GUI check): canBecomeKey=true plus becomesKeyOnlyIfNeeded lets
        // SwiftUI controls (slider/buttons) respond to the mouse. With canBecomeKey=false the controls die and
        // the panel wasn't exposed to the AX tree either (auto-verified). The .nonactivatingPanel styleMask blocks app activation (focus theft),
        // so even when key it keeps the previous app's focus (verified: after a click appActive=false, frontmost unchanged).
        becomesKeyOnlyIfNeeded = true
        minSize = NSSize(width: 180, height: 120)
    }
    override var canBecomeKey: Bool { true }

    /// pin toggle: always-on-top (.floating) ↔ normal (.normal). isFloatingPanel is matched to the level too.
    /// re-assert hidesOnDeactivate=false on every toggle: insurance so the cross-app always-visible invariant (set in init)
    /// isn't shaken by any AppKit flag interaction.
    func applyPinned(_ pinned: Bool) {
        hidesOnDeactivate = false
        level = pinned ? .floating : .normal
        isFloatingPanel = pinned
    }
}
