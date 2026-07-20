import AppKit
import UserNotifications
import StickyCastCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var store: StickyStore!
    private(set) var controllers: [UUID: StickyPanelController] = [:]  // 강한 참조 — 놓으면 패널이 사라짐 (iter-009)
    private(set) var recentErrors: [String] = []  // 메뉴바 "최근 오류" (Task 11)
    private var statusMenu: StatusMenuController!

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
        // 파싱 前 값싼 URL 길이 컷 (거대 URL을 디코드 前에 차단). 정확한 콘텐츠 한도는 store.add()가 강제.
        // .count는 grapheme 수지만 유효 sticky:// URL은 순수 ASCII(prefix + base64url)라 바이트 수와 동일.
        guard url.absoluteString.count <= maxReceivedURLLength else {
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
            addController(for: note)
        case .failure(.capReached):
            reportError("스티커가 최대 \(StickyStore.maxStickies)장입니다. 기존 스티커를 닫아 주세요.")
        case .failure(.contentTooLarge):
            reportError("스티커 내용이 너무 큽니다 (최대 약 \(StickyStore.maxContentBytes / (1024 * 1024))MB).")
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
        let controller = StickyPanelController(note: note, store: store) { [weak self] id in
            self?.controllers[id] = nil
        }
        controllers[note.id] = controller
        controller.show()
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
    /// 매 실행 확인 — 첫 실행 이후 핸들러 하이재킹도 감지 (스펙 §7의 "첫 실행"보다 견고).
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
