// Task 3 스파이크 (Task 9에서 StickyContentView로 대체)
import SwiftUI
import MarkdownUI

struct SpikeContentView: View {
    @State private var hovering = false
    @State private var opacity: Double = 1.0
    let onClose: () -> Void
    let onOpacity: (Double) -> Void
    private let sample = """
    # 스파이크 🎉
    - 한글 **볼드** 확인
    - [링크](https://example.com)

    ```swift
    let code = "block"
    ```
    \(String(repeating: "긴 본문 줄입니다. ", count: 60))
    """

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                Markdown(sample)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if hovering {
                HStack(spacing: 8) {
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill").imageScale(.large)
                    }.buttonStyle(.plain)
                    Slider(value: $opacity, in: 0.3...1.0)
                        .frame(width: 100)
                        .onChange(of: opacity) { _, v in onOpacity(v) }
                    Spacer()
                }
                .padding(8)
                .background(.thinMaterial)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onHover { hovering = $0 }
    }
}
