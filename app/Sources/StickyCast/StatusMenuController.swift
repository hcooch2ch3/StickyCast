import AppKit
import StickyCastCore

/// 메뉴바 아이콘 — LSUIElement 앱의 유일한 상시 진입점 (§5.3)
final class StatusMenuController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private unowned let appDelegate: AppDelegate

    init(appDelegate: AppDelegate) {
        self.appDelegate = appDelegate
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(error: false)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    private func setIcon(error: Bool) {
        let symbol = error ? "exclamationmark.triangle.fill" : "note.text"
        statusItem.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "StickyCast")
    }

    /// §7 폴백: 알림이 권한 거부 등으로 안 보일 수 있으므로, 오류 시 아이콘을 배지로 바꿔
    /// 사용자가 메뉴를 열지 않아도 오류 발생을 알 수 있게 한다. 메뉴를 열면(=오류가 상단에 보이면) 해제.
    func indicateError() {
        setIcon(error: true)
    }

    // 열 때마다 현재 상태로 재구성
    func menuNeedsUpdate(_ menu: NSMenu) {
        setIcon(error: false)
        menu.removeAllItems()

        // §7: 최근 오류는 메뉴 최상단 — 사용자가 다른 항목보다 먼저 보도록 (iter-011)
        if !appDelegate.recentErrors.isEmpty {
            menu.addItem(withTitle: "⚠︎ 최근 오류", action: nil, keyEquivalent: "")
            for err in appDelegate.recentErrors {
                menu.addItem(withTitle: "  \(String(err.prefix(50)))", action: nil, keyEquivalent: "")
            }
            menu.addItem(.separator())
        }

        // 메뉴는 살아있는 컨트롤러가 있는 노트만 나열 — store와 controllers가 어긋나도
        // 클릭이 조용히 무시되는 항목을 만들지 않는다.
        let liveNotes = appDelegate.store.notes.filter { appDelegate.controllers[$0.id] != nil }
        if liveNotes.isEmpty {
            menu.addItem(withTitle: "스티커 없음", action: nil, keyEquivalent: "")
        } else {
            for note in liveNotes {
                let preview = note.content
                    .split(separator: "\n").first.map(String.init) ?? "(빈 내용)"
                let item = NSMenuItem(
                    title: String(preview.prefix(40)),
                    action: #selector(bringNoteToFront(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = note.id
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        // 스티커가 있을 때만 토글 표시. 라벨은 실제 가시성에서 파생(하나라도 보이면 "숨기기", 전부 숨겨졌으면 "보이기").
        if !liveNotes.isEmpty {
            if appDelegate.anyStickerVisible {
                menu.addItem(makeItem("모두 숨기기", #selector(hideAllStickers)))
            } else {
                menu.addItem(makeItem("모두 보이기", #selector(showAllStickers)))
            }
        }
        menu.addItem(makeItem("모두 앞으로", #selector(bringAllToFront)))
        menu.addItem(makeItem("모두 닫기", #selector(closeAll)))
        menu.addItem(.separator())
        menu.addItem(makeItem("StickyCast에 관하여", #selector(showAbout)))
        menu.addItem(makeItem("종료", #selector(quit), key: "q"))
    }

    private func makeItem(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        return item
    }

    @objc private func bringNoteToFront(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? UUID else { return }
        appDelegate.controllers[id]?.bringToFrontHighlighted()  // §5.3 "앞으로 + 강조"
    }
    @objc private func bringAllToFront() {
        appDelegate.controllers.values.forEach { $0.bringToFront() }
    }
    @objc private func hideAllStickers() { appDelegate.hideAllStickers() }
    @objc private func showAllStickers() { appDelegate.showAllStickers() }
    @objc private func closeAll() {
        // close()가 controllers에서 항목을 제거하므로 스냅샷 후 순회 (순회 중 변형 방지)
        Array(appDelegate.controllers.values).forEach { $0.close() }
    }
    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: NSAttributedString(string:
                "Markdown rendering: swift-markdown-ui (MIT)\nMarkEdit companion tool")
        ])
        NSApp.activate()  // About 패널만 예외적으로 활성화 (macOS 14 non-deprecated)
    }
    @objc private func quit() { NSApp.terminate(nil) }
}
