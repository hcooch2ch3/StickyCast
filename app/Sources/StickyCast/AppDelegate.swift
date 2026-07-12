import AppKit
import UserNotifications
import StickyCastCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var store: StickyStore!
    private(set) var controllers: [UUID: StickyPanelController] = [:]  // 강한 참조 — 놓으면 패널이 사라짐 (iter-009)
    private(set) var recentErrors: [String] = []  // 메뉴바 "최근 오류" (Task 11)

    // limits.ts의 MAX_URL_LENGTH(43*1024)와 동일 상수 — 계약 단일 소스를 Swift 측에 미러링 (iter-007).
    private let maxReceivedURLLength = 43 * 1024

    // launch 완료 전 도착한 URL 큐 (store nil 크래시 방지, iter-010). 정상 경로에선 비지만 순서 불변식을 강제.
    private var pendingURLs: [URL] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let screen = NSScreen.main?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        store = StickyStore(defaults: .standard, screenFrame: screen)

        // 알림 권한: 첫 실행 시 요청 (§7 — 첫 에러 시점 요청은 그 에러를 증발시킴)
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }

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
        )
        NSLog("StickyCast error: %@", message)
    }

    private func errorMessage(for error: StickyURLError) -> String {
        switch error {
        case .unknownHost: return "지원하지 않는 요청입니다 (v1은 sticky://new만 지원)."
        case .missingContent: return "내용이 비어 있습니다."
        case .invalidEncoding: return "내용을 해석할 수 없습니다 (인코딩 오류)."
        }
    }
}
