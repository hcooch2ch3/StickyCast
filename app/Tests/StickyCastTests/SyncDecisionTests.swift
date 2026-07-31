import XCTest
@testable import StickyCastCore

final class SyncDecisionTests: XCTestCase {
    func testNilSyncedHashIgnores() {
        // 미시드 → 외부변경 감지 불가, 안전 무시 (스펙 §8.1)
        XCTAssertEqual(decideSyncAction(stickerHash: "s", fileHash: "f", syncedHash: nil, isEditing: false), .ignore)
        XCTAssertEqual(decideSyncAction(stickerHash: "s", fileHash: "f", syncedHash: nil, isEditing: true), .ignore)
    }
    func testFileUnchangedIgnores() {
        // 파일 해시 == syncedHash → 실제 변경 없음(touch-only) → 무시 (dirty여도)
        XCTAssertEqual(decideSyncAction(stickerHash: "x", fileHash: "base", syncedHash: "base", isEditing: false), .ignore)
        XCTAssertEqual(decideSyncAction(stickerHash: "edited", fileHash: "base", syncedHash: "base", isEditing: true), .ignore)
    }
    func testCleanFileChangedAutoApplies() {
        // 스티커 clean(sticker==synced) + 파일 변경 → 자동 반영
        XCTAssertEqual(decideSyncAction(stickerHash: "base", fileHash: "new", syncedHash: "base", isEditing: false), .autoApply)
    }
    func testConverged() {
        // 파일 == 스티커(양쪽 같은 내용) 이면서 syncedHash와는 다름 → 수렴
        XCTAssertEqual(decideSyncAction(stickerHash: "same", fileHash: "same", syncedHash: "old", isEditing: false), .converged)
    }
    func testDirtyFileChangedConflicts() {
        // 스티커 편집(sticker != synced) + 파일 변경, 내용 다름 → 충돌
        XCTAssertEqual(decideSyncAction(stickerHash: "mine", fileHash: "theirs", syncedHash: "base", isEditing: false), .conflict)
    }
    func testEditingTreatedAsDirty() {
        // 편집 중이면 sticker==synced여도 dirty로 취급 → 충돌 (미커밋 편집 clobber 방지)
        XCTAssertEqual(decideSyncAction(stickerHash: "base", fileHash: "new", syncedHash: "base", isEditing: true), .conflict)
    }
}
