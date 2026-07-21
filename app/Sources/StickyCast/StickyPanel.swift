import AppKit

final class StickyPanel: NSPanel {
    init(frame: NSRect) {
        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .borderless, .resizable],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = false   // 기본 비고정. 핀 토글 시 applyPinned가 재조정.
        level = .normal           // 기본: 비고정(작업 앱에 덮여 화면을 가리지 않음). 핀 시 applyPinned가 .floating으로.
        // collectionBehavior 유지(canJoinAllSpaces): 페이즈 1은 모든 Space 추종 유지 —
        // 제거하면 nonactivating 앱에서 off-Space 노트 도달 불가 회귀(계획 A안). Space 스코핑은 페이즈 2(허브).
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

    /// 핀 토글: 항상-위(.floating) ↔ 평범(.normal). isFloatingPanel도 레벨과 짝을 맞춘다.
    /// hidesOnDeactivate=false를 매 토글 재확인 — cross-app 상시노출 불변식(§init)이 어떤 AppKit
    /// 플래그 상호작용에도 흔들리지 않게 하는 보험 (dual-review iter-003, critic).
    func applyPinned(_ pinned: Bool) {
        hidesOnDeactivate = false
        level = pinned ? .floating : .normal
        isFloatingPanel = pinned
    }
}
