import SwiftUI
import MarkdownUI

struct StickyContentView: View {
    let content: String
    let initialOpacity: Double
    let onClose: () -> Void
    let onOpacityChange: (Double) -> Void  // 슬라이더 이동 중 (패널 alpha만, 저장 안 함)
    let onOpacityCommit: (Double) -> Void  // 슬라이더 놓을 때 (저장)

    @State private var hovering = false
    @State private var opacity: Double

    init(content: String, initialOpacity: Double,
         onClose: @escaping () -> Void,
         onOpacityChange: @escaping (Double) -> Void,
         onOpacityCommit: @escaping (Double) -> Void) {
        self.content = content
        self.initialOpacity = initialOpacity
        self.onClose = onClose
        self.onOpacityChange = onOpacityChange
        self.onOpacityCommit = onOpacityCommit
        _opacity = State(initialValue: initialOpacity)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                Markdown(content)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if hovering {
                HStack(spacing: 8) {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").imageScale(.large)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("스티커 닫기")
                    Slider(value: $opacity, in: 0.3...1.0) { editing in
                        // live 업데이트는 .onChange가 전담. 여기선 드래그 종료 시 커밋만 (iter-009).
                        if !editing { onOpacityCommit(opacity) }
                    }
                    .frame(width: 100)
                    .onChange(of: opacity) { _, v in onOpacityChange(v) }
                    Spacer()
                }
                .padding(8)
                .background(.thinMaterial)
                .transition(.opacity)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
    }
}
