import SwiftUI

/// 충돌 배너 상태. (Live Sync — Task 8에서 렌더)
enum SyncBanner: Equatable { case conflict }

/// 노트별 반응형 상태 — Live Sync가 살아있는 스티커 뷰에 반영되도록 하는 경로(스펙 §4.5).
/// 기존 init-seed @State는 파일 변경을 못 밀어넣어 stale해지므로, 컨트롤러가 이 vm을 갱신한다.
/// 스레드 계약: **메인 스레드 전용**(StickyStore와 동일). AppKit/SwiftUI 콜백은 전부 메인.
/// @MainActor를 안 붙이는 이유: nonisolated StickyPanelController.init에서 생성해야 하고,
/// 코드베이스가 actor 대신 문서 계약으로 메인 스레드를 강제한다.
final class StickyViewModel: ObservableObject {
    @Published var content: String
    @Published var isLinked: Bool                  // 파일 연결 여부 — detach 시 false로 → 🔗/⬆️ 반응형 숨김
    @Published var syncBanner: SyncBanner? = nil   // 충돌 시 배너 (Task 8)
    @Published var autoSyncPulse: Bool = false     // clean 자동 반영 인디케이터 트리거 (Task 8)
    @Published var oversize: Bool = false          // 연결 파일이 maxContentBytes 초과 (§8.2, Task 8)
    /// 인라인 편집 중 여부 — Live Sync 판정이 dirty 입력으로 참조(§2). 미커밋 편집 clobber 방지.
    private(set) var isEditing: Bool = false

    init(content: String, isLinked: Bool = false) {
        self.content = content
        self.isLinked = isLinked
    }

    func setEditing(_ v: Bool) { isEditing = v }
}
