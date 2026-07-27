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
    let onContentChange: ((String) -> Bool)?   // 인라인 편집 저장 콜백. 성공 여부 반환(실패 시 편집 유지). nil이면 편집 비활성
    let isLinked: Bool                          // 파일 연결 스티커 여부 → "원본에 저장" 버튼 노출
    let onSaveToFile: (() -> Bool)?             // 현재 내용을 원본 파일에 수동 반영 (연결 스티커만). 성공 여부 반환.

    @State private var hovering = false
    @State private var opacity: Double
    @State private var pinned: Bool
    // 인라인 편집 (S1 스파이크 — nonactivating 패널에서 TextEditor 키 입력 검증)
    @State private var isEditing = false
    // 저장 후 읽기 모드 렌더 소스 (let content는 초기값). Phase 1은 패널이 복원 시 새로 생성돼 stale 안 됨.
    // ⚠️ Phase 2(Live Sync): 파일 변경이 살아있는 노트를 갱신하면 이 init-seed @State가 stale해짐 —
    // 그땐 observable 소스에서 구동해야 함 (리뷰 Minor 지적, 지금은 latent).
    @State private var displayContent: String
    @State private var draft: String = ""
    @FocusState private var editorFocused: Bool
    // "원본에 저장" 결과 즉각 피드백 — 성공 초록 체크 / 실패 빨강 X, ~1.2s 후 복귀
    private enum SaveFlash { case success, failure }
    @State private var saveFlash: SaveFlash? = nil

    init(content: String, initialOpacity: Double, initialPinned: Bool,
         onClose: @escaping () -> Void,
         onTogglePin: @escaping (Bool) -> Void,
         onOpacityChange: @escaping (Double) -> Void,
         onOpacityCommit: @escaping (Double) -> Void,
         onContentChange: ((String) -> Bool)? = nil,
         isLinked: Bool = false,
         onSaveToFile: (() -> Bool)? = nil) {
        self.content = content
        self.initialOpacity = initialOpacity
        self.initialPinned = initialPinned
        self.onClose = onClose
        self.onTogglePin = onTogglePin
        self.onOpacityChange = onOpacityChange
        self.onOpacityCommit = onOpacityCommit
        self.onContentChange = onContentChange
        self.isLinked = isLinked
        self.onSaveToFile = onSaveToFile
        _opacity = State(initialValue: initialOpacity)
        _pinned = State(initialValue: initialPinned)
        _displayContent = State(initialValue: content)
    }

    private func beginEdit() {
        guard onContentChange != nil else { return }   // 편집 비활성 스티커
        draft = displayContent
        isEditing = true
        // TextEditor 마운트 후에 포커스 — 같은 tick에 설정하면 필드가 아직 뷰 트리에 없어
        // @FocusState 쓰기가 no-op 될 수 있음 (리뷰 Major: 첫 진입 포커스 실패 방지).
        DispatchQueue.main.async { editorFocused = true }
    }
    private func commitEdit() {
        // 저장 실패(예: 1MB 초과)면 편집 모드 유지 + displayContent 갱신 안 함 (컨트롤러가 오류 알림).
        // §7 조용한 실패 금지 — 편집이 소리 없이 사라지지 않게.
        let ok = onContentChange?(draft) ?? true
        guard ok else { return }
        displayContent = draft
        isEditing = false
    }
    private func cancelEdit() {
        isEditing = false   // draft 폐기
    }

    // "원본에 저장" 버튼 아이콘/색 — 평시 ⬆️, 성공 ✓(초록), 실패 ✗(빨강)
    private var saveIconName: String {
        switch saveFlash {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.circle.fill"
        case nil:      return "arrow.up.doc"
        }
    }
    private var saveIconColor: Color {
        switch saveFlash {
        case .success: return .green
        case .failure: return .red
        case nil:      return .secondary
        }
    }
    private func flashSaveResult(_ ok: Bool) {
        withAnimation { saveFlash = ok ? .success : .failure }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { saveFlash = nil }
        }
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

                // 편집 버튼 — 편집 가능 스티커(onContentChange != nil). 더블클릭 대안 진입점 (스펙 §3.2.1)
                if onContentChange != nil, !isEditing {
                    Button(action: beginEdit) {
                        Image(systemName: "pencil").imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("편집")
                }
                // 원본에 저장 — 파일 연결 스티커만. 편집 내용을 원본 .md에 수동 반영 + 결과 시각 피드백.
                if isLinked, let onSaveToFile, !isEditing {
                    Button(action: { flashSaveResult(onSaveToFile()) }) {
                        Image(systemName: saveIconName)
                            .imageScale(.medium)
                            .foregroundStyle(saveIconColor)
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.plain)
                    .disabled(saveFlash != nil)
                    .accessibilityLabel(saveFlash == .success ? "저장됨" : "원본 파일에 저장")
                    .help("원본 파일에 저장")
                }
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").imageScale(.medium)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스티커 닫기")
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.thinMaterial.opacity(hovering ? 1.0 : 0.55))

            // 본문 — 읽기(Markdown) ↔ 편집(TextEditor)
            if isEditing {
                VStack(spacing: 4) {
                    TextEditor(text: $draft)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .focused($editorFocused)
                        .onExitCommand(perform: cancelEdit)   // Esc → 취소
                    HStack(spacing: 8) {
                        Spacer()
                        Button("취소", action: cancelEdit)
                            .keyboardShortcut(.cancelAction)
                        Button("저장", action: commitEdit)
                            .keyboardShortcut(.return, modifiers: .command)   // ⌘Enter → 저장
                    }
                    .controlSize(.small)
                    .padding(.horizontal, 8).padding(.bottom, 6)
                }
            } else {
                ScrollView {
                    Markdown(displayContent)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: beginEdit)   // 더블클릭 → 편집 (스펙 §3.2.1)
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
