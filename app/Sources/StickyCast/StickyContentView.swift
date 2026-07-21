import SwiftUI
import MarkdownUI

struct StickyContentView: View {
    let content: String
    let initialOpacity: Double
    let initialPinned: Bool
    let onClose: () -> Void
    let onTogglePin: (Bool) -> Void
    let onOpacityChange: (Double) -> Void
    let onOpacityCommit: (Double) -> Void

    @State private var hovering = false
    @State private var opacity: Double
    @State private var pinned: Bool

    init(content: String, initialOpacity: Double, initialPinned: Bool,
         onClose: @escaping () -> Void,
         onTogglePin: @escaping (Bool) -> Void,
         onOpacityChange: @escaping (Double) -> Void,
         onOpacityCommit: @escaping (Double) -> Void) {
        self.content = content
        self.initialOpacity = initialOpacity
        self.initialPinned = initialPinned
        self.onClose = onClose
        self.onTogglePin = onTogglePin
        self.onOpacityChange = onOpacityChange
        self.onOpacityCommit = onOpacityCommit
        _opacity = State(initialValue: initialOpacity)
        _pinned = State(initialValue: initialPinned)
    }

    var body: some View {
        VStack(spacing: 0) {
            // 상단 크롬바 — 상시 노출(호버 시 진해짐). 좌:핀 / 중앙:그립 / 우:닫기
            HStack(spacing: 8) {
                Button(action: { pinned.toggle(); onTogglePin(pinned) }) {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .imageScale(.medium)
                        .foregroundStyle(pinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pinned ? "핀 해제" : "핀 고정")

                Spacer(minLength: 0)
                Image(systemName: "line.3.horizontal")          // ⋯ 드래그 그립 어포던스
                    .imageScale(.small).foregroundStyle(.secondary.opacity(0.5))
                Spacer(minLength: 0)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").imageScale(.medium)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스티커 닫기")
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.thinMaterial.opacity(hovering ? 1.0 : 0.55))

            // 본문
            ScrollView {
                Markdown(content)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 하단 투명도 — 상시(얇게)
            HStack(spacing: 6) {
                Image(systemName: "circle.lefthalf.filled")
                    .imageScale(.small).foregroundStyle(.secondary)
                Slider(value: $opacity, in: 0.3...1.0) { editing in
                    if !editing { onOpacityCommit(opacity) }
                }
                .onChange(of: opacity) { _, v in onOpacityChange(v) }
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(.thinMaterial.opacity(hovering ? 1.0 : 0.4))
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
    }
}
