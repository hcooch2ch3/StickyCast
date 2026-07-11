// Task 2 스켈레톤 (Task 10에서 확장)
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    // 검증 노트: NSLog는 unified logging에서 <private>로 가려져 pre-flight 판독이 불가.
    // 스켈레톤 한정으로 파일 로그를 병행한다 (Task 10에서 제거).
    private let preflightLog = URL(fileURLWithPath: "/tmp/stickycast-preflight.log")
    private var spikePanel: StickyPanel?  // Task 3 스파이크 (Task 10에서 제거)

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("StickyCast launched")
        // 수신자 신원 기록 — 스테일 Launch Services 등록(옛 사본이 수신)을 로그에서 판별 가능하게 (iter-002 리뷰)
        append("launched bundle=\(Bundle.main.bundlePath)")
        showSpikePanel()
    }

    // Task 3: 통합 인터랙션 스파이크 — 요구 인터랙션 전부를 한 패널에서 증명
    private func showSpikePanel() {
        let panel = StickyPanel(frame: NSRect(x: 200, y: 200, width: 320, height: 380))
        let host = NSHostingView(rootView: SpikeContentView(
            onClose: { [weak self] in self?.spikePanel?.orderOut(nil) },
            onOpacity: { [weak self] v in self?.spikePanel?.alphaValue = v }
        ))
        panel.contentView = host
        panel.orderFrontRegardless()
        spikePanel = panel

        // 자가진단: 창 속성이 계약대로 설정됐는지 파일 로그로 덤프 (Task 3 자동 검증)
        let sm = panel.styleMask
        append("spike-panel level=\(panel.level.rawValue) floating=\(panel.isFloatingPanel) " +
               "canBecomeKey=\(panel.canBecomeKey) nonactivating=\(sm.contains(.nonactivatingPanel)) " +
               "borderless=\(sm.contains(.borderless)) resizable=\(sm.contains(.resizable)) " +
               "movableByBG=\(panel.isMovableByWindowBackground) " +
               "allSpaces=\(panel.collectionBehavior.contains(.canJoinAllSpaces)) " +
               "hidesOnDeactivate=\(panel.hidesOnDeactivate) worksWhenModal=\(panel.worksWhenModal) " +
               "appActive=\(NSApp.isActive)")
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            let line = "RECEIVED length=\(url.absoluteString.count) prefix=\(String(url.absoluteString.prefix(40)))"
            NSLog("%@", line)
            append(line)
        }
    }

    private func append(_ line: String) {
        let stamped = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        if let data = stamped.data(using: .utf8) {
            if let handle = try? FileHandle(forWritingTo: preflightLog) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                try? data.write(to: preflightLog)
            }
        }
    }
}
