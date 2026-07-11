// Task 2 스켈레톤 (Task 10에서 확장)
import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
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

    // Task 3: 통합 인터랙션 스파이크 — 요구 인터랙션 전부를 한 패널에서 증명 (cliclick 합성 이벤트 하네스)
    private func showSpikePanel() {
        // 화면 좌상단 고정 (topLeft ~100,100) — 하네스 좌표 예측 쉽게
        let screenH = NSScreen.main?.frame.height ?? 1080
        let panel = StickyPanel(frame: NSRect(x: 100, y: screenH - 100 - 380, width: 320, height: 380))
        let host = NSHostingView(rootView: SpikeContentView(
            onClose: { [weak self] in
                self?.append("EVENT onClose fired")   // 3: ✕ 버튼 실작동
                self?.spikePanel?.orderOut(nil)
            },
            onOpacity: { [weak self] v in
                self?.append(String(format: "EVENT opacity=%.3f", v))  // 3: 슬라이더 실작동
                self?.spikePanel?.alphaValue = v
            },
            onHarness: { [weak self] in
                self?.append("EVENT harness-tap")   // 이벤트 전달 격리 검증 (호버 무관)
            }
        ))
        panel.contentView = host
        panel.delegate = self   // 4: windowDidMove 관측
        panel.orderFrontRegardless()
        spikePanel = panel

        // 자가진단: 창 속성 + cliclick용 top-left 스크린 좌표 덤프
        let sm = panel.styleMask
        append("spike-panel level=\(panel.level.rawValue) floating=\(panel.isFloatingPanel) " +
               "canBecomeKey=\(panel.canBecomeKey) nonactivating=\(sm.contains(.nonactivatingPanel)) " +
               "borderless=\(sm.contains(.borderless)) resizable=\(sm.contains(.resizable)) " +
               "movableByBG=\(panel.isMovableByWindowBackground) " +
               "allSpaces=\(panel.collectionBehavior.contains(.canJoinAllSpaces)) " +
               "hidesOnDeactivate=\(panel.hidesOnDeactivate) worksWhenModal=\(panel.worksWhenModal) " +
               "appActive=\(NSApp.isActive)")
        append(cliclickCoords(panel))
    }

    /// AppKit bottom-left → cliclick top-left 스크린 좌표. 슬라이더/본문 지점을 미리 계산해 로그.
    private func cliclickCoords(_ panel: NSWindow) -> String {
        guard let screen = NSScreen.main else { return "coords: no screen" }
        let f = panel.frame
        let screenH = screen.frame.height
        let topLeftY = screenH - (f.origin.y + f.height)   // 창 상단
        let winX = f.origin.x
        // SpikeContentView 상단 크롬(HStack padding 8): ✕(~22)·spacing·Slider(width 100)
        let sliderLeftX = Int(winX) + 40, sliderRightX = Int(winX) + 130
        let chromeY = Int(topLeftY) + 20
        let bodyX = Int(winX + f.width/2), bodyY = Int(topLeftY + f.height/2)
        return "coords winTopLeft=(\(Int(winX)),\(Int(topLeftY))) " +
               "sliderLeft=(\(sliderLeftX),\(chromeY)) sliderRight=(\(sliderRightX),\(chromeY)) " +
               "closeBtn=(\(Int(winX)+18),\(chromeY)) body=(\(bodyX),\(bodyY))"
    }

    func windowDidMove(_ notification: Notification) {
        if let f = spikePanel?.frame {
            append("EVENT windowDidMove origin=(\(Int(f.origin.x)),\(Int(f.origin.y)))")  // 4: 드래그 이동
        }
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
