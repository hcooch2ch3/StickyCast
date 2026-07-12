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
        // Task 3 확정 (2026-07-12 GUI 검증): canBecomeKey=true + becomesKeyOnlyIfNeeded로
        // SwiftUI 컨트롤(슬라이더/버튼)이 마우스로 조작 가능. canBecomeKey=false에선 컨트롤이 죽고
        // 패널이 AX 트리에도 노출 안 됐음(자동 검증). .nonactivatingPanel styleMask가 앱 활성화(포커스 탈취)를
        // 막으므로 key여도 이전 앱 포커스 유지 (검증: 클릭 후 appActive=false, frontmost 불변).
        becomesKeyOnlyIfNeeded = true
        minSize = NSSize(width: 180, height: 120)
    }
    override var canBecomeKey: Bool { true }
}
