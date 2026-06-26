import AppKit

@MainActor
final class StatusBarManager {
    static let shared = StatusBarManager()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var popoverManager: PopoverManager?
    private var rightClickMenu: NSMenu?

    private init() {
        setupStatusBarButton()
        setupRightClickMenu()
    }

    private func setupStatusBarButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(systemSymbolName: "brain.head.profile", accessibilityDescription: "AI Suit")
        button.image?.size = NSSize(width: 18, height: 18)
        button.target = self
        button.action = #selector(statusBarButtonClicked(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func setupRightClickMenu() {
        let menu = NSMenu()
        let prefsItem = NSMenuItem(title: "偏好设置…", action: #selector(showPreferences), keyEquivalent: ",")
        prefsItem.target = self
        menu.addItem(prefsItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "退出 SnapAI", action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        self.rightClickMenu = menu
    }

    func configure(popoverManager: PopoverManager) { self.popoverManager = popoverManager }

    @objc private func statusBarButtonClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            if let menu = rightClickMenu {
                statusItem.menu = menu
                sender.performClick(nil)
                statusItem.menu = nil
            }
        } else {
            popoverManager?.toggle(from: sender)
        }
    }

    @objc private func showPreferences() { SettingsWindowManager.shared.showSettings() }
    @objc private func quitApplication() { NSApplication.shared.terminate(nil) }
}
