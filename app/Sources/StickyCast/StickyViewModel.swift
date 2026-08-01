import SwiftUI

/// conflict banner state. (Live Sync, rendered in Task 8)
enum SyncBanner: Equatable { case conflict }

/// per-note reactive state: the path that lets Live Sync reach a live sticker view (spec §4.5).
/// the old init-seed @State can't push file changes in and goes stale, so the controller updates this vm.
/// threading contract: **main-thread only** (same as StickyStore). AppKit/SwiftUI callbacks all run on main.
/// no @MainActor because it has to be created in the nonisolated StickyPanelController.init, and
/// the codebase enforces main-thread by documented contract rather than an actor.
final class StickyViewModel: ObservableObject {
    @Published var content: String
    @Published var isLinked: Bool                  // whether a file is linked: false on detach → reactively hides 🔗/⬆️
    @Published var syncBanner: SyncBanner? = nil   // banner on conflict (Task 8)
    @Published var autoSyncPulse: Bool = false     // trigger for the clean auto-sync indicator (Task 8)
    @Published var oversize: Bool = false          // linked file exceeds maxContentBytes (§8.2, Task 8)
    /// whether an inline edit is in progress: Live Sync reads this as dirty input (§2). Prevents clobbering uncommitted edits.
    private(set) var isEditing: Bool = false

    init(content: String, isLinked: Bool = false) {
        self.content = content
        self.isLinked = isLinked
    }

    func setEditing(_ v: Bool) { isEditing = v }
}
