import XCTest
@testable import StickyCastCore

final class SyncDecisionTests: XCTestCase {
    func testNilSyncedHashIgnores() {
        // unseeded → cannot detect external changes, safely ignore (spec §8.1)
        XCTAssertEqual(decideSyncAction(stickerHash: "s", fileHash: "f", syncedHash: nil, isEditing: false), .ignore)
        XCTAssertEqual(decideSyncAction(stickerHash: "s", fileHash: "f", syncedHash: nil, isEditing: true), .ignore)
    }
    func testFileUnchangedIgnores() {
        // file hash == syncedHash → no real change (touch-only) → ignore (even when dirty)
        XCTAssertEqual(decideSyncAction(stickerHash: "x", fileHash: "base", syncedHash: "base", isEditing: false), .ignore)
        XCTAssertEqual(decideSyncAction(stickerHash: "edited", fileHash: "base", syncedHash: "base", isEditing: true), .ignore)
    }
    func testCleanFileChangedAutoApplies() {
        // sticker clean (sticker==synced) + file changed → auto-apply
        XCTAssertEqual(decideSyncAction(stickerHash: "base", fileHash: "new", syncedHash: "base", isEditing: false), .autoApply)
    }
    func testConverged() {
        // file == sticker (both same content) but differs from syncedHash → converged
        XCTAssertEqual(decideSyncAction(stickerHash: "same", fileHash: "same", syncedHash: "old", isEditing: false), .converged)
    }
    func testDirtyFileChangedConflicts() {
        // sticker edited (sticker != synced) + file changed, contents differ → conflict
        XCTAssertEqual(decideSyncAction(stickerHash: "mine", fileHash: "theirs", syncedHash: "base", isEditing: false), .conflict)
    }
    func testEditingTreatedAsDirty() {
        // while editing, treat as dirty even if sticker==synced → conflict (prevents clobbering uncommitted edits)
        XCTAssertEqual(decideSyncAction(stickerHash: "base", fileHash: "new", syncedHash: "base", isEditing: true), .conflict)
    }
}
