import AppKit
import UserNotifications
import StickyCastCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var store: StickyStore!
    private(set) var controllers: [UUID: StickyPanelController] = [:]  // 강한 참조 — 놓으면 패널이 사라짐 (iter-009)
    private(set) var recentErrors: [String] = []  // 메뉴바 "최근 오류" (Task 11)
    private var statusMenu: StatusMenuController!

    // 이중 방어 (계약 §크기한도 "양측 강제"). 파싱 前 값싼 URL 길이 컷으로 비정상 URL을 먼저 거르고,
    // 파싱 後 디코드된 콘텐츠 바이트를 확장과 동일한 1MB로 강제 — sticky://를 직접 쏘는 rogue 발신자가
    // 확장의 콘텐츠 캡을 우회하는 경로까지 닫는다 (재리뷰 자가검증).
    private let maxReceivedURLLength = 2 * 1024 * 1024        // 파싱 前 값싼 상한
    private let maxContentBytes = 1 * 1024 * 1024             // 확장 MAX_CONTENT_BYTES와 동일 (원문 1MB)

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
        // 수신측 oversize 거부 (계약 §크기한도 "양측 강제" — OS 진입점이라 확장 외 발신자도 가능).
        // 파서가 아니라 URL 원문을 쥔 이 최전선에서 판정 (iter-007 리뷰: 소유 경계 = AppDelegate).
        guard url.absoluteString.count <= maxReceivedURLLength else {
            reportError("스티커 내용이 너무 큽니다.")
            return
        }
        switch StickyURLParser.parse(url) {
        case .success(let content):
            // 콘텐츠 바이트 캡 강제 (확장과 동일 1MB) — rogue 발신자의 저장·렌더 지뢰 차단
            guard content.utf8.count <= maxContentBytes else {
                reportError("스티커 내용이 너무 큽니다.")
                return
            }
            createSticky(content: content)
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
        }
    }

    private func restoreStickies() {
        store.restore()
        for note in store.notes {
            addController(for: note)
        }
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
