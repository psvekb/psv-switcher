import AppKit

final class StatusBarController {
    private let statusItem: NSStatusItem
    private let manager: EventTapManager
    private var enabledItem: NSMenuItem?

    init(manager: EventTapManager) {
        self.manager = manager
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "PS"
        }
        let menu = NSMenu()
        let enabled = NSMenuItem(title: "Включено", action: #selector(toggleEnabled), keyEquivalent: "")
        enabled.target = self
        enabled.state = .on
        menu.addItem(enabled)
        self.enabledItem = enabled
        menu.addItem(NSMenuItem.separator())
        let quit = NSMenuItem(title: "Выход", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        statusItem.menu = menu
    }

    @objc private func toggleEnabled() {
        let newState = !(enabledItem?.state == .on)
        manager.setEnabled(newState)
        enabledItem?.state = newState ? .on : .off
        enabledItem?.title = newState ? "Включено" : "Выключено"
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}