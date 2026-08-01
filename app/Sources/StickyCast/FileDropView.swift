import AppKit

/// 메뉴바 아이콘에 `.md`/`.markdown` 파일을 드롭하면 스티커로 여는 드롭 대상 (§5, Task 12).
///
/// `statusItem.button` 위에 겹쳐 드롭만 수신한다. 마우스 클릭(메뉴 열기)은 별도 오버라이드 없이
/// 기본 responder 체인으로 아래 버튼에 전달된다(S3 스파이크에서 드롭 수신 확인, 클릭은 수동 검증).
/// 마크다운이 아닌 파일이 섞이면 드래그오버 자체를 거부(하이라이트·수락 안 함).
final class FileDropView: NSView {
    private let onDrop: ([URL]) -> Void
    private var highlighted = false { didSet { if oldValue != highlighted { needsDisplay = true } } }

    init(onDrop: @escaping ([URL]) -> Void) {
        self.onDrop = onDrop
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }
    required init?(coder: NSCoder) { fatalError("not supported") }

    // 마우스 이벤트는 이 뷰를 통과해 아래 statusItem.button(메뉴 열기)이 받게 한다.
    // 드롭 목적지 등록(registerForDraggedTypes)은 dragging-destination 경로라 hitTest를 안 타므로
    // nil 반환에도 드롭은 그대로 수신된다 → 클릭 통과를 macOS 버전에 무관하게 보장(dual-review 2차).
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard !markdownURLs(sender).isEmpty else { return [] }   // .md 없으면 수락 안 함
        highlighted = true
        return .copy
    }
    override func draggingExited(_ sender: NSDraggingInfo?) { highlighted = false }
    override func draggingEnded(_ sender: NSDraggingInfo) { highlighted = false }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        highlighted = false
        let urls = markdownURLs(sender)
        guard !urls.isEmpty else { return false }
        onDrop(urls)
        return true
    }

    /// 드롭 페이스트보드에서 .md/.markdown URL만 추출(복수 파일 지원).
    private func markdownURLs(_ sender: NSDraggingInfo) -> [URL] {
        let urls = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
        let exts: Set<String> = ["md", "markdown"]
        return urls.filter { exts.contains($0.pathExtension.lowercased()) }
    }

    // 드래그오버 하이라이트(Step 2) — 아이콘 뒤에 은은한 둥근 배경.
    override func draw(_ dirtyRect: NSRect) {
        guard highlighted else { return }
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.35).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
    }
}
