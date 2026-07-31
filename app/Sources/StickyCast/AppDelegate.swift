import AppKit
import UserNotifications
import UniformTypeIdentifiers
import StickyCastCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var store: StickyStore!
    private(set) var controllers: [UUID: StickyPanelController] = [:]  // 강한 참조 — 놓으면 패널이 사라짐 (iter-009)
    private(set) var recentErrors: [String] = []  // 메뉴바 "최근 오류" (Task 11)
    private var statusMenu: StatusMenuController!
    let fileWatcher = FileWatcher()               // Live Sync — 연결 스티커 파일 감시 (§4)
    private var suppressedNotes: Set<UUID> = []   // ⬆️ 저장 직후 self-write 억제 (§3.2, Task 11)

    // "모두 숨기기/보이기" 토글 라벨은 별도 상태 bool이 아니라 실제 창 가시성에서 파생한다
    // (dual-review iter-006: 전역 bool은 per-window 상태와 어긋나 라벨이 거짓말함).
    var anyStickerVisible: Bool { controllers.values.contains { $0.isVisible } }

    // 파싱 前 값싼 URL 길이 상한 (비정상적으로 큰 URL을 디코드 前에 컷). 정확한 콘텐츠 바이트 한도는
    // StickyStore.maxContentBytes 단일 소스가 add()/restore() 양쪽에서 강제한다 (재리뷰: 상수 통합·restore 갭).
    private let maxReceivedURLLength = 2 * 1024 * 1024

    // launch 완료 전 도착한 URL 큐 (store nil 크래시 방지, iter-010). 정상 경로에선 비지만 순서 불변식을 강제.
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        store = StickyStore(defaults: .standard, screenFrame: screen)

        // 메뉴바를 URL 처리보다 먼저 세워, 이후 reportError의 배지 표시가 유효하도록 (iter-010 §7 폴백)
        statusMenu = StatusMenuController(appDelegate: self)

        // 알림 권한: 첫 실행 시 요청 (§7 — 첫 에러 시점 요청은 그 에러를 증발시킴)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

        verifySchemeHandler()

        restoreStickies()

        // launch 전 큐잉된 URL 처리
        let queued = pendingURLs
        pendingURLs = []
        queued.forEach(handle(url:))
    }

    // 앱 종료 시 pending 이동 커밋 flush — 디바운스 창(300ms)에서 종료 시 최종 위치 유실 방지 (iter-009)
    func applicationWillTerminate(_ notification: Notification) {
        controllers.values.forEach { $0.flushPendingMove() }
        fileWatcher.unwatchAll()   // Live Sync 감시 정리(§4)
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        // store가 아직 없으면(launch 전) 큐잉 후 launch에서 처리 (iter-010)
        guard store != nil else {
            pendingURLs.append(contentsOf: urls)
            return
        }
        urls.forEach(handle(url:))
    }

    private func handle(url: URL) {
        // 파싱 前 값싼 URL 길이 컷 (거대 URL을 디코드 前에 차단, 바이트 기준). 정확한 콘텐츠 한도는 store.add()가 강제.
        // .utf8.count로 바이트 판정 — 멀티바이트 다수인 rogue URL이 grapheme 수 과소계수로 컷을 우회하지 못하게.
        guard url.absoluteString.utf8.count <= maxReceivedURLLength else {
            reportError("스티커 내용이 너무 큽니다.")
            return
        }
        switch StickyURLParser.parse(url) {
        case .success(let content):
            createSticky(content: content)   // 콘텐츠 바이트 캡은 store.add()가 강제 (단일 소스)
        case .failure(let error):
            reportError(errorMessage(for: error))
        }
    }

    private func createSticky(content: String) {
        switch store.add(content: content) {
        case .success(let note):
            addController(for: note)   // 새 스티커는 show()로 뜸 → anyStickerVisible이 자동으로 true
        case .failure(.capReached):
            reportError("스티커가 최대 \(StickyStore.maxStickies)장입니다. 기존 스티커를 닫아 주세요.")
        case .failure(.contentTooLarge):
            reportError("스티커 내용이 너무 큽니다 (최대 약 \(StickyStore.maxContentBytes / (1024 * 1024))MB).")
        case .failure(.noteNotFound):
            break   // add는 이 에러를 반환하지 않음 (스위치 망라용 방어)
        }
    }

    private func restoreStickies() {
        let outcome = store.restore()
        for note in store.notes {
            addController(for: note)
        }
        // §7: 복원 시 노트를 버렸으면 조용히 넘어가지 않고 사용자에게 알린다 (수신 경로와 일관).
        guard outcome.hasDrops else { return }
        var parts: [String] = []
        if outcome.droppedOversize > 0 { parts.append("크기 초과 \(outcome.droppedOversize)개") }
        if outcome.droppedOverCap > 0 { parts.append("최대 장수 초과 \(outcome.droppedOverCap)개") }
        reportError("이전 스티커 \(parts.joined(separator: ", "))를 복원하지 못했습니다.")
    }

    private func addController(for note: StickyNote) {
        let controller = StickyPanelController(
            note: note, store: store,
            onClosed: { [weak self] id in
                self?.fileWatcher.unwatch(noteID: id)   // 닫기 시 감시 정리(§4 누수 방지)
                self?.controllers[id] = nil
            },
            onSaveToFile: { [weak self] id in self?.saveNoteToSourceFile(id: id) ?? false },
            onError: { [weak self] message in self?.reportError(message) },
            onTakeFile: { [weak self] id in self?.takeFileForNote(id: id) },
            onDetach: { [weak self] id in self?.detachNote(id: id) },
            onReveal: { [weak self] id in self?.revealNoteInFinder(id: id) },
            onOpenEditor: { [weak self] id in self?.openNoteInEditor(id: id) }
        )
        controllers[note.id] = controller
        controller.show()
        // 연결 스티커면 Live Sync 감시 arm (§3/§4)
        if note.sourcePath != nil, let url = resolveSourceURL(note: note) {
            fileWatcher.watch(noteID: note.id, url: url) { [weak self] in
                self?.handleFileEvent(noteID: note.id)
            }
        }
    }

    /// FileWatcher 이벤트 → off-main 읽기 → (dirty,file) 판정 → vm 갱신 (§3). 삭제/이동도 처리(§7).
    private func handleFileEvent(noteID: UUID) {
        if suppressedNotes.contains(noteID) { return }   // ⬆️ self-write 억제 창(§3.2)
        guard let note = store.notes.first(where: { $0.id == noteID }),
              let controller = controllers[noteID] else { return }
        // 이동 추적: bookmark로 현재 경로 resolve. 없거나 파일 부재면 삭제 처리(§7, debounce는 FileWatcher가 이미 수행).
        guard let url = resolveSourceURL(note: note), FileManager.default.fileExists(atPath: url.path) else {
            handleDeletedFile(noteID: noteID)
            return
        }
        // 경로가 바뀌었으면(동일 볼륨 이동) sourcePath·bookmark 갱신 + watcher 재-arm(§7)
        if url.path != note.sourcePath {
            store.setSourcePath(id: noteID, path: url.path, bookmark: try? url.bookmarkData())
            fileWatcher.watch(noteID: noteID, url: url) { [weak self] in self?.handleFileEvent(noteID: noteID) }
        }
        readLinkedFile(url) { [weak self] result in
            guard let self, let result else { return }   // 읽기/decode 실패 → no-op(자동반영 금지, M2)
            guard let note = self.store.notes.first(where: { $0.id == noteID }) else { return }
            let stickerHash = ContentHash.sha256Hex(note.content)
            switch decideSyncAction(stickerHash: stickerHash, fileHash: result.hash,
                                    syncedHash: note.syncedHash, isEditing: controller.vm.isEditing) {
            case .ignore:
                break
            case .converged:
                self.store.setSyncedHash(id: noteID, hash: result.hash)
            case .autoApply:
                switch self.store.applyFileSync(id: noteID, content: result.content, hash: result.hash) {
                case .success:
                    controller.vm.content = result.content
                    controller.vm.oversize = false
                    controller.vm.autoSyncPulse.toggle()
                case .failure(.contentTooLarge):
                    controller.vm.oversize = true   // 지속 인디케이터(§8.2), 알림 폭풍 아님
                case .failure:
                    break
                }
            case .conflict:
                controller.vm.syncBanner = .conflict
            }
        }
    }

    /// 연결 파일 삭제(debounce·resolve 후에도 부재) → "유지(독립 전환)/닫기" 다이얼로그 (§7).
    private func handleDeletedFile(noteID: UUID) {
        guard let note = store.notes.first(where: { $0.id == noteID }) else { return }
        let name = (note.sourcePath as NSString?)?.lastPathComponent ?? "파일"
        let alert = NSAlert()
        alert.messageText = "연결된 파일을 찾을 수 없습니다"
        alert.informativeText = "'\(name)'이(가) 삭제/이동됐습니다. 스티커를 어떻게 할까요? (현재 내용은 보존됩니다)"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "유지 (독립 전환)")
        alert.addButton(withTitle: "닫기")
        NSApp.activate()
        if alert.runModal() == .alertFirstButtonReturn {
            detachNote(id: noteID)          // 유지 → 독립 전환(내용 보존)
        } else {
            controllers[noteID]?.close()    // 닫기 → 제거 (close가 unwatch 경유)
        }
    }

    /// 연결 해제 — 감시 중단 + 링크 메타 제거(내용 보존) + vm 반영(🔗/⬆️ 숨김) (§6).
    func detachNote(id: UUID) {
        fileWatcher.unwatch(noteID: id)
        store.detachFromFile(id: id)
        controllers[id]?.vm.isLinked = false
        controllers[id]?.vm.syncBanner = nil
        controllers[id]?.vm.oversize = false
    }
    /// Finder에서 원본 보기 (§6).
    func revealNoteInFinder(id: UUID) {
        guard let note = store.notes.first(where: { $0.id == id }), let url = resolveSourceURL(note: note) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    /// 원본을 기본 편집기로 열기 — §2.1.1 "원본에서 편집" 경로 (§6).
    func openNoteInEditor(id: UUID) {
        guard let note = store.notes.first(where: { $0.id == id }), let url = resolveSourceURL(note: note) else { return }
        NSWorkspace.shared.open(url)
    }

    /// 충돌 배너 "파일 내용 가져오기" — 파일 버전을 강제로 로드(스티커 편집 폐기), 배너 해제 (§3.1).
    func takeFileForNote(id: UUID) {
        guard let note = store.notes.first(where: { $0.id == id }),
              let controller = controllers[id],
              let url = resolveSourceURL(note: note) else { return }
        readLinkedFile(url) { [weak self] result in
            guard let self else { return }
            defer { controller.vm.syncBanner = nil }
            guard let result else { return }   // 읽기 실패 시 배너만 닫고 no-op
            switch self.store.applyFileSync(id: id, content: result.content, hash: result.hash) {
            case .success:
                controller.vm.content = result.content
                controller.vm.oversize = false
            case .failure(.contentTooLarge):
                controller.vm.oversize = true
            case .failure:
                break
            }
        }
    }

    /// 파일을 off-main UTF-8로 읽어 (내용, 해시)를 main으로 콜백. 실패 시 nil(자동반영 금지).
    func readLinkedFile(_ url: URL, completion: @escaping ((content: String, hash: String)?) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result: (String, String)? = (try? String(contentsOf: url, encoding: .utf8))
                .map { ($0, ContentHash.sha256Hex($0)) }
            DispatchQueue.main.async { completion(result) }
        }
    }

    /// 모든 스티커를 화면에서 감춘다(비파괴 — 노트·컨트롤러 유지). 메뉴바에서 호출.
    func hideAllStickers() { controllers.values.forEach { $0.hide() } }
    /// 감춘 스티커를 모두 다시 앞으로 띄운다.
    func showAllStickers() { controllers.values.forEach { $0.show() } }

    // MARK: 편의 기능 Phase 1 — 클립보드 · 파일 열기 · 내보내기 (스펙 §3.1/§3.4)

    /// 클립보드 텍스트로 독립 스티커 생성. 메뉴바 "클립보드에서 스티커".
    func createStickyFromClipboard() {
        guard let raw = NSPasteboard.general.string(forType: .string),
              !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            reportError("클립보드에 붙여넣을 텍스트가 없습니다.")
            return
        }
        createSticky(content: raw)   // 콘텐츠 바이트 캡은 store.add()가 강제 (단일 소스)
    }

    /// NSOpenPanel로 .md 선택 → 내용을 스티커로. 링크 메타(sourcePath/bookmark)를 저장하되
    /// Phase 1은 스티커를 독립(편집 가능)으로 둔다 (스펙 §4.1.1). 읽기전용·Live Sync는 Phase 2.
    func openMarkdownFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        // .md / .markdown / 일반 텍스트 허용 (.txt는 마크다운 여부 불명확이나 텍스트로 열람 허용)
        var types: [UTType] = [.plainText]
        if let markdown = UTType(filenameExtension: "markdown") { types.insert(markdown, at: 0) }
        if let md = UTType(filenameExtension: "md") { types.insert(md, at: 0) }
        panel.allowedContentTypes = types
        NSApp.activate()   // accessory(LSUIElement) 앱 — 패널을 앞으로 가져온다
        guard panel.runModal() == .OK, let url = panel.url else { return }
        openFile(at: url)
    }

    private func openFile(at url: URL) {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            reportError("파일을 읽을 수 없습니다 (\(url.lastPathComponent)). UTF-8 텍스트인지 확인해 주세요.")
            return
        }
        // Phase 1: 일반 bookmark 저장(비샌드박스에서 동작). Phase 2가 sandbox 전환 시
        // security-scoped bookmark(.withSecurityScope)로 승격 + FileWatcher 연결 (스펙 §1.1/§4.3).
        let bookmark = try? url.bookmarkData()
        // 원본 mtime 스냅샷 — write-back 시 외부 변경(다른 에디터가 파일 수정) 감지 기준.
        // save-back과 동일하게 심링크 해소 후 읽어 mtime 기준을 일치시킨다 (심링크면 첫 저장 오탐 방지).
        let mtime = fileModificationDate(url.resolvingSymlinksInPath())
        switch store.add(content: content, sourcePath: url.path, sourceBookmark: bookmark, sourceModifiedDate: mtime) {
        case .success(let note):
            // open 시점 syncedHash 시딩(§8.1 세 시점 중 ①) — watch arm 전에 기준선 확보.
            // 없으면 첫 외부 변경에 헛 배너 + ⬆️ 오판(회귀).
            store.setSyncedHash(id: note.id, hash: ContentHash.sha256Hex(content))
            addController(for: note)
        case .failure(.capReached):
            reportError("스티커가 최대 \(StickyStore.maxStickies)장입니다. 기존 스티커를 닫아 주세요.")
        case .failure(.contentTooLarge):
            reportError("파일이 너무 큽니다 (최대 약 \(StickyStore.maxContentBytes / (1024 * 1024))MB).")
        case .failure(.noteNotFound):
            break   // add는 이 에러를 반환하지 않음 (스위치 망라용 방어)
        }
    }

    /// 파일 연결 스티커의 현재 내용을 원본 .md 파일에 수동 반영 (사용자 명시 동작).
    /// 양방향 자동 동기화(스펙 §2.1이 배제)가 아니라, 버튼 누를 때만 스티커→파일 단방향 기록 =
    /// 그 순간 단일 writer라 충돌 회피. Live Sync(파일→스티커, Phase 2)와 독립.
    /// 성공 시 true — 호출부(스티커 버튼)가 즉각 시각 피드백(체크/X)을 주도록. 실패는 reportError로 상세 알림.
    @discardableResult
    func saveNoteToSourceFile(id: UUID) -> Bool {
        guard let note = store.notes.first(where: { $0.id == id }), note.sourcePath != nil else { return false }
        guard let resolved = resolveSourceURL(note: note) else {
            reportError("원본 파일을 찾을 수 없습니다. 이동/삭제됐을 수 있습니다.")
            return false
        }
        // 심링크는 실제 대상으로 해소 후 기록 — atomically:true의 rename이 링크를 일반 파일로
        // 치환해 vault 심링크 구조를 깨는 것을 방지 (리뷰 B Major).
        let url = resolved.resolvingSymlinksInPath()

        // 충돌 감지: 열었을 때(또는 마지막 저장 시)의 mtime과 현재 파일 mtime이 다르면
        // 외부 에디터가 파일을 바꾼 것 → 무경고 덮어쓰기(=사용자 작업 소실) 대신 확인 (리뷰 Critical).
        let currentMtime = fileModificationDate(url)
        if let baseline = note.sourceModifiedDate, let current = currentMtime, current != baseline {
            guard confirmOverwrite(fileName: url.lastPathComponent) else { return false }
        }

        do {
            try note.content.write(to: url, atomically: true, encoding: .utf8)
            // 저장 후 새 mtime을 기준으로 갱신 — 다음 저장이 방금 우리 쓰기를 "외부 변경"으로 오판하지 않게.
            store.setSourceModifiedDate(id: id, date: fileModificationDate(url))
            return true
        } catch {
            reportError("원본 파일에 저장하지 못했습니다 (\(url.lastPathComponent)).")
            return false
        }
    }

    /// 원본이 외부에서 변경됐을 때만 뜨는 덮어쓰기 확인. 사용자가 "덮어쓰기"를 골라야 true.
    private func confirmOverwrite(fileName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "원본 파일이 외부에서 변경되었습니다"
        alert.informativeText = "'\(fileName)'을(를) 스티커 내용으로 덮어쓰면 외부 변경분이 사라집니다. 계속할까요?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "덮어쓰기")
        alert.addButton(withTitle: "취소")
        NSApp.activate()
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// 파일 mtime. 읽기 실패 시 nil (충돌 감지는 nil이면 건너뛰고 저장 허용 — 감지 못 함 ≠ 차단).
    private func fileModificationDate(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate]) as? Date
    }

    /// bookmark로 현재 경로를 resolve(파일 이동 추적). 실패 시 sourcePath 문자열로 폴백.
    /// (stale bookmark 재생성·재저장은 Phase 2 — 현재 일반 bookmark라 영향 낮음.)
    private func resolveSourceURL(note: StickyNote) -> URL? {
        if let data = note.sourceBookmark {
            var stale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) {
                return url
            }
        }
        if let path = note.sourcePath { return URL(fileURLWithPath: path) }
        return nil
    }

    /// 스티커 본문을 .md로 저장. 메뉴바 "스티커 내보내기 ▸ <노트>".
    func exportNote(id: UUID) {
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
        let panel = NSSavePanel()
        if let md = UTType(filenameExtension: "md") { panel.allowedContentTypes = [md] }
        panel.nameFieldStringValue = ExportNaming.filename(for: note.content)
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try note.content.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            reportError("내보내기에 실패했습니다 (\(url.lastPathComponent)).")
        }
    }

    /// §7 조용한 실패 금지: 알림 시도 + 메뉴바 최근 오류에 항상 적재 (권한 무관 폴백)
    func reportError(_ message: String) {
        recentErrors = Array((recentErrors + [message]).suffix(5))
        let content = UNMutableNotificationContent()
        content.title = "StickyCast"
        content.body = message
        UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        ) { error in
            if let error { NSLog("StickyCast notification add failed: %@", "\(error)") }  // 조용한 실패 금지 (iter-011)
        }
        NSLog("StickyCast error: %@", message)
        statusMenu?.indicateError()  // §7 폴백: 알림이 안 보여도 메뉴바 아이콘 배지로 알림
    }

    /// §7: sticky:// 핸들러가 이 앱인지 자가 확인. bundleIdentifier로 비교(symlink 견고),
    /// nil(핸들러 미등록)도 오류로 취급, .app 번들에서만 실행(swift run false-positive 방지, iter-011).
    /// 앱 실행 시 1회 확인(매 URL 아님) — 다음 실행에서 핸들러 하이재킹도 감지 (스펙 §7의 "첫 실행 1회"보다 견고).
    private func verifySchemeHandler() {
        guard Bundle.main.bundleURL.pathExtension == "app",
              let probe = URL(string: "sticky://new") else { return }
        let myID = Bundle.main.bundleIdentifier
        guard let handlerURL = NSWorkspace.shared.urlForApplication(toOpen: probe) else {
            reportError("sticky:// 핸들러가 등록되지 않았습니다. 스티커 발사가 동작하지 않습니다 — 앱을 다시 설치해 주세요.")
            return
        }
        if Bundle(url: handlerURL)?.bundleIdentifier != myID {
            reportError("sticky:// 핸들러가 이 앱이 아닙니다 (현재: \(handlerURL.lastPathComponent)). 앱을 다시 설치해 주세요.")
        }
    }

    private func errorMessage(for error: StickyURLError) -> String {
        switch error {
        case .unknownHost: return "지원하지 않는 요청입니다 (v1은 sticky://new만 지원)."
        case .missingContent: return "내용이 비어 있습니다."
        case .invalidEncoding: return "내용을 해석할 수 없습니다 (인코딩 오류)."
        }
    }
}
