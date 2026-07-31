import Foundation

/// Live Sync 판정 결과 (스펙 §3의 (dirty, file-changed) 2×2).
public enum SyncDecision: Equatable {
    case ignore      // 파일 실제 변경 없음(touch-only) 또는 미시드 → 무시
    case autoApply   // 파일만 변경, 스티커 clean → 자동 반영
    case converged   // 양쪽이 같은 내용에 도달 → syncedHash만 갱신
    case conflict    // 스티커 dirty + 파일 변경, 내용 다름 → 충돌 배너
}

/// FileWatcher 이벤트 시 새 파일 내용을 읽고 어떤 동작을 할지 판정한다(스펙 §3).
/// - Parameters:
///   - stickerHash: 스티커 현재 내용 해시
///   - fileHash: 새 파일 내용 해시
///   - syncedHash: 마지막 동기 기준선 (nil=미시드)
///   - isEditing: 인라인 편집 중(미커밋 draft) 여부 — dirty로 취급(§2 활성 편집 clobber 방지)
public func decideSyncAction(stickerHash: String, fileHash: String, syncedHash: String?, isEditing: Bool) -> SyncDecision {
    // 미시드(open/restore 시딩 전)면 외부변경 감지 불가 → 안전 무시(스펙 §8.1).
    guard let syncedHash else { return .ignore }
    let fileChanged = (fileHash != syncedHash)
    if !fileChanged { return .ignore }                 // F=false 가드(맨 앞) — touch-only/자기저장 재-arm 헛 배너 방지
    if fileHash == stickerHash { return .converged }   // 수렴
    let dirty = isEditing || (stickerHash != syncedHash)
    return dirty ? .conflict : .autoApply
}
