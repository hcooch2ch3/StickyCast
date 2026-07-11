import AppKit

final class StickyPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true   // 본문 드래그 이동
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        // cross-app 스티커의 핵심: 다른 앱이 활성화돼도 숨지 않아야 함. NSPanel 기본값이
        // config마다 다르므로 명시적으로 고정 (iter-003 리뷰: 미설정 시 always-visible 무력화 위험).
        hidesOnDeactivate = false
        minSize = NSSize(width: 180, height: 120)
    }
    override var canBecomeKey: Bool { false }  // v1 뷰어 전용 — 예약 확장(update) 시 재검토. 스파이크 3번 실패 시 true+becomesKeyOnlyIfNeeded 재시도 (plan Task 3)
}
