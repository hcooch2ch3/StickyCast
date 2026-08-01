import SwiftUI
import MarkdownUI

struct StickyContentView: View {
    @ObservedObject var vm: StickyViewModel     // reactive content, banner, edit state (§4.5)
    let initialOpacity: Double
    let initialPinned: Bool
    let onClose: () -> Void
    let onTogglePin: (Bool) -> Void
    let onOpacityChange: (Double) -> Void
    let onOpacityCommit: (Double) -> Void
    let onContentChange: ((String) -> Bool)?   // inline-edit save callback. Returns success (on failure, keeps editing). nil disables editing.
    let onSaveToFile: (() -> Bool)?             // push current content back to the source file (linked stickers only). Returns success.
    let onDetach: (() -> Void)?                 // unlink (🔗 popover)
    let onRevealInFinder: (() -> Void)?         // reveal in Finder
    let onOpenInEditor: (() -> Void)?           // open in the source editor
    let onColorChange: ((String?) -> Void)?     // change sticky-note color (nil = default)
    let onTakeFile: (() -> Void)?               // conflict banner "pull file content" (linked stickers only)

    @Environment(\.colorScheme) private var systemColorScheme
    @State private var hovering = false
    @State private var opacity: Double
    @State private var pinned: Bool
    // inline editing (S1 spike: verify TextEditor key input in a nonactivating panel)
    @State private var isEditing = false
    // read-mode render source is vm.content (reactive). When Live Sync updates vm.content it re-renders at once (§4.5).
    @State private var draft: String = ""
    @FocusState private var editorFocused: Bool
    // instant feedback on "save to source": green check on success, red X on failure, reverts after ~1.2s
    private enum SaveFlash { case success, failure }
    @State private var saveFlash: SaveFlash? = nil
    // sticky-note color: swatch popover plus current selection (key is persisted via callback, applied instantly via @State)
    @State private var colorKey: String?
    @State private var showColorPicker = false
    @State private var pulseVisible = false      // brief top highlight on clean auto-sync
    @State private var showLinkPopover = false    // 🔗 link info / unlink popover

    init(vm: StickyViewModel, initialOpacity: Double, initialPinned: Bool,
         onClose: @escaping () -> Void,
         onTogglePin: @escaping (Bool) -> Void,
         onOpacityChange: @escaping (Double) -> Void,
         onOpacityCommit: @escaping (Double) -> Void,
         onContentChange: ((String) -> Bool)? = nil,
         onSaveToFile: (() -> Bool)? = nil,
         initialColor: String? = nil,
         onColorChange: ((String?) -> Void)? = nil,
         onTakeFile: (() -> Void)? = nil,
         onDetach: (() -> Void)? = nil,
         onRevealInFinder: (() -> Void)? = nil,
         onOpenInEditor: (() -> Void)? = nil) {
        _vm = ObservedObject(wrappedValue: vm)
        self.initialOpacity = initialOpacity
        self.initialPinned = initialPinned
        self.onClose = onClose
        self.onTogglePin = onTogglePin
        self.onOpacityChange = onOpacityChange
        self.onOpacityCommit = onOpacityCommit
        self.onContentChange = onContentChange
        self.onSaveToFile = onSaveToFile
        self.onDetach = onDetach
        self.onRevealInFinder = onRevealInFinder
        self.onOpenInEditor = onOpenInEditor
        self.onColorChange = onColorChange
        self.onTakeFile = onTakeFile
        _colorKey = State(initialValue: initialColor)
        _opacity = State(initialValue: initialOpacity)
        _pinned = State(initialValue: initialPinned)
    }

    private func beginEdit() {
        guard onContentChange != nil else { return }   // editing-disabled sticker
        draft = vm.content
        isEditing = true
        vm.setEditing(true)   // makes Live Sync treat this as dirty (§2 prevents clobbering uncommitted edits)
        // focus after TextEditor mounts: setting it on the same tick can be a no-op because
        // the field isn't in the view tree yet (review Major: prevents focus failure on first entry).
        DispatchQueue.main.async { editorFocused = true }
    }
    private func commitEdit() {
        // on save failure (e.g. over 1MB), stay in edit mode and don't update vm.content (controller shows the error).
        // §7 no silent failures: don't let an edit vanish without a trace.
        let ok = onContentChange?(draft) ?? true
        guard ok else { return }
        vm.content = draft
        isEditing = false
        vm.setEditing(false)
    }
    private func cancelEdit() {
        isEditing = false   // discard draft
        vm.setEditing(false)
    }

    // icon/color for the "save to source" button: ⬆️ at rest, ✓ (green) on success, ✗ (red) on failure
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
    // a single color swatch: on selection, apply instantly, persist via callback, and close the popover. key=nil means "default".
    @ViewBuilder
    private func colorSwatch(key: String?, color: Color?) -> some View {
        let isSelected = (key == colorKey)
        Button(action: {
            colorKey = key
            onColorChange?(key)
            showColorPicker = false
        }) {
            Circle()
                .fill(color ?? Color(nsColor: .windowBackgroundColor))
                .frame(width: 20, height: 20)
                .overlay {   // default (no color) shows a slash
                    if color == nil {
                        Image(systemName: "line.diagonal")
                            .imageScale(.small).foregroundStyle(.secondary)
                    }
                }
                .overlay {   // selection-indicator border
                    Circle().strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.4),
                                          lineWidth: isSelected ? 2 : 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(StickyPalette(rawValue: key ?? "")?.label ?? "기본")
    }

    private func flashSaveResult(_ ok: Bool) {
        withAnimation { saveFlash = ok ? .success : .failure }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation { saveFlash = nil }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // top chrome bar, always visible (darkens on hover). Left: close, pin / center: opacity / right: edit, save
            HStack(spacing: 8) {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill").imageScale(.medium)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("스티커 닫기")

                Button(action: { pinned.toggle(); onTogglePin(pinned) }) {
                    Image(systemName: pinned ? "pin.fill" : "pin")
                        .imageScale(.medium)
                        .foregroundStyle(pinned ? Color.accentColor : Color.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(pinned ? "핀 해제" : "핀 고정")

                // color: swatch popover (sticky-note presets)
                if onColorChange != nil {
                    Button(action: { showColorPicker.toggle() }) {
                        Image(systemName: "paintpalette")
                            .imageScale(.medium)
                            .foregroundStyle(StickyPalette.color(forKey: colorKey) != nil ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("색상")
                    .popover(isPresented: $showColorPicker, arrowEdge: .bottom) {
                        HStack(spacing: 8) {
                            colorSwatch(key: nil, color: nil)   // default
                            ForEach(StickyPalette.allCases) { colorSwatch(key: $0.rawValue, color: $0.color) }
                        }
                        .padding(10)
                    }
                }

                Spacer(minLength: 4)
                // opacity: before the right-side buttons, fixed narrow (moved from the bottom bar to the top). Width capped so it doesn't dominate.
                Image(systemName: "circle.lefthalf.filled")
                    .imageScale(.small).foregroundStyle(.secondary)
                Slider(value: $opacity, in: 0.3...1.0) { editing in
                    if !editing { onOpacityCommit(opacity) }
                }
                .onChange(of: opacity) { _, v in onOpacityChange(v) }
                .controlSize(.mini)
                .frame(width: 70)
                .accessibilityLabel("투명도")

                // edit button: editable stickers only (onContentChange != nil). Alternate entry point to double-click (spec §3.2.1)
                if onContentChange != nil, !isEditing {
                    Button(action: beginEdit) {
                        Image(systemName: "pencil").imageScale(.medium)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("편집")
                }
                // 🔗 link indicator / popover: file-linked stickers only
                if vm.isLinked, !isEditing {
                    Button(action: { showLinkPopover.toggle() }) {
                        Image(systemName: "link").imageScale(.medium).foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("파일 연결")
                    .popover(isPresented: $showLinkPopover, arrowEdge: .bottom) {
                        VStack(alignment: .leading, spacing: 6) {
                            Button("Finder에서 보기") { showLinkPopover = false; onRevealInFinder?() }
                            Button("원본 편집기로 열기") { showLinkPopover = false; onOpenInEditor?() }
                            Divider()
                            Button("연결 해제") { showLinkPopover = false; onDetach?() }
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                    }
                }
                // save to source: file-linked stickers only. Push edits back to the source .md, with visual result feedback.
                if vm.isLinked, let onSaveToFile, !isEditing {
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
            }
            .padding(.horizontal, 8).padding(.vertical, 5)
            .background(.thinMaterial.opacity(hovering ? 1.0 : 0.55))

            // conflict banner: shown when both sides changed (§3.1). Sits above the edit UI (edits kept). Default is to ignore = non-destructive.
            if vm.syncBanner == .conflict {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text("파일과 스티커가 모두 변경됨").font(.caption)
                    Spacer(minLength: 4)
                    Button("파일 가져오기") { onTakeFile?() }
                    Button("내 편집 유지") { vm.syncBanner = nil }
                }
                .controlSize(.small)
                .padding(.horizontal, 8).padding(.vertical, 5)
                .background(Color.yellow.opacity(0.18))
            }
            // file-oversize indicator: persistent (not a repeating toast, §8.2)
            if vm.oversize {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle").foregroundStyle(.red)
                    Text("연결 파일이 너무 큼 (최대 1MB) — 반영 안 됨").font(.caption2).foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 8).padding(.vertical, 3)
            }

            // body: read (Markdown) ↔ edit (TextEditor)
            if isEditing {
                VStack(spacing: 4) {
                    TextEditor(text: $draft)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .focused($editorFocused)
                        .onExitCommand(perform: cancelEdit)   // Esc → cancel
                    HStack(spacing: 8) {
                        Spacer()
                        Button("취소", action: cancelEdit)
                            .keyboardShortcut(.cancelAction)
                        Button("저장", action: commitEdit)
                            .keyboardShortcut(.return, modifiers: .command)   // ⌘Enter → save
                    }
                    .controlSize(.small)
                    .padding(.horizontal, 8).padding(.bottom, 6)
                }
            } else {
                ScrollView {
                    Markdown(vm.content)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .contentShape(Rectangle())
                .onTapGesture(count: 2, perform: beginEdit)   // double-click → edit (spec §3.2.1)
            }
        }
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(StickyPalette.color(forKey: colorKey) ?? Color(nsColor: .windowBackgroundColor)))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        // with a color (light pastel), force the light appearance so text stays black and chrome stays consistently light. Default keeps the system appearance.
        .environment(\.colorScheme, colorKey != nil ? .light : systemColorScheme)
        .overlay(alignment: .top) {   // auto-sync flash (§4.5 autoSyncPulse)
            Rectangle().fill(Color.accentColor).frame(height: 2)
                .opacity(pulseVisible ? 1 : 0)
        }
        .onChange(of: vm.autoSyncPulse) { _, _ in
            pulseVisible = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                withAnimation { pulseVisible = false }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .onHover { hovering = $0 }
    }
}
