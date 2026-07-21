import AppKit
import SwiftUI
import StickyCastCore

/// 스티커 창 하나의 생명주기. 리사이즈는 windowDidEndLiveResize에서, 이동은 디바운스로 commit.
/// 스레드 계약: 메인 스레드 전용 (StickyStore와 동일 — UI 콜백/URL 핸들러 전부 메인).
final class StickyPanelController: NSObject, NSWindowDelegate {
    let noteID: UUID
    private let panel: StickyPanel
    private let store: StickyStore
    private let onClosed: (UUID) -> Void
    private var moveDebounce: Timer?
    private var committedOpacity: Double   // 하이라이트 복원 기준 (panel.alphaValue의 transient 값 대신)
    private var isFlashing = false         // 하이라이트 재진입 가드

    init(note: StickyNote, store: StickyStore, onClosed: @escaping (UUID) -> Void) {
        self.noteID = note.id
        self.store = store
        self.onClosed = onClosed
        self.committedOpacity = note.opacity
        self.panel = StickyPanel(frame: note.frame)
        super.init()

        panel.alphaValue = note.opacity
        panel.delegate = self
        panel.contentView = NSHostingView(rootView: StickyContentView(
            content: note.content,
            initialOpacity: note.opacity,
            initialPinned: note.pinned == true,
            onClose: { [weak self] in self?.close() },
            onTogglePin: { [weak self] pinned in         // 진실한 핀 배선(dual-review iter-004 #1) — Task 6에서 생성 시 초기 적용 추가
                guard let self else { return }
                self.store.setPinned(id: self.noteID, pinned: pinned)
                self.panel.applyPinned(pinned)
            },
            onOpacityChange: { [weak self] v in self?.panel.alphaValue = v },
            onOpacityCommit: { [weak self] v in
                guard let self else { return }
                self.panel.alphaValue = v
                self.committedOpacity = v
                self.store.commitOpacity(id: self.noteID, opacity: v)
            }
        ))
    }

    deinit { moveDebounce?.invalidate() }

    /// 이동 디바운스에 pending이 남아 있으면 즉시 커밋 (앱 종료 시 최종 위치 유실 방지, iter-009).
    /// Task 10의 applicationWillTerminate가 모든 컨트롤러에 호출한다.
    func flushPendingMove() {
        guard moveDebounce != nil else { return }
        moveDebounce?.invalidate()
        moveDebounce = nil
        store.commitFrame(id: noteID, frame: panel.frame)
    }

    func show() { panel.orderFrontRegardless() }
    func bringToFront() { panel.orderFrontRegardless() }

    /// §5.3 "앞으로 + 강조": 알파를 잠깐 낮췄다 복원하는 플래시.
    /// 복원 기준은 committedOpacity(커밋된 값)이며 panel.alphaValue(transient)가 아니다 —
    /// 재진입/슬라이더 중 잘못된 값으로 복원되는 것을 막는다 (iter-009).
    func bringToFrontHighlighted() {
        panel.orderFrontRegardless()
        guard !isFlashing else { return }   // 진행 중이면 재진입 무시
        isFlashing = true
        let base = committedOpacity
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.12
            panel.animator().alphaValue = max(0.3, base - 0.5)
        }, completionHandler: { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.25
                self.panel.animator().alphaValue = self.committedOpacity   // 최신 커밋값으로 복원
            }, completionHandler: { [weak self] in
                self?.isFlashing = false
            })
        })
    }

    func close() {
        moveDebounce?.invalidate()   // pending 이동 커밋 정리 (remove 후라 flush 불필요)
        moveDebounce = nil
        store.remove(id: noteID)
        panel.orderOut(nil)
        onClosed(noteID)
    }

    // MARK: NSWindowDelegate — 연속 제스처는 종료 시점에만 저장 (§5.2)
    // AppKit에는 "드래그 종료" 노티피케이션이 없고 windowDidMove는 드래그 중 반복 호출된다.
    // Timer는 .default 런루프 모드라 드래그 중(.eventTracking)엔 발화하지 않고 mouseUp 후에만
    // 발화한다 = gesture-end 커밋 (iter-009 검증). .common 모드였다면 mid-drag 발화로 §5.2 위반.
    func windowDidMove(_ notification: Notification) {
        moveDebounce?.invalidate()
        moveDebounce = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.store.commitFrame(id: self.noteID, frame: self.panel.frame)
            self.moveDebounce = nil
        }
    }
    func windowDidEndLiveResize(_ notification: Notification) {
        moveDebounce?.invalidate()   // 원점 이동 리사이즈의 이중 커밋 방지
        moveDebounce = nil
        store.commitFrame(id: noteID, frame: panel.frame)
    }
}
