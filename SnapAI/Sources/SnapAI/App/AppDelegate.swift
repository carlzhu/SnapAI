import AppKit
import Cocoa

/// Pure-menu-bar application delegate.
final class AppDelegate: NSObject, NSApplicationDelegate, @unchecked Sendable {

    private var selfMonitorTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = Self.buildMainMenu()
        let popoverManager = PopoverManager.shared
        StatusBarManager.shared.configure(popoverManager: popoverManager)
        startSelfMonitor()
    }

    /// 即使是 .accessory（菜单栏）应用，也需要一个包含标准“编辑”菜单的主菜单，
    /// 否则 ⌘C/⌘V/⌘X/⌘A/⌘Z 等键盘快捷键不会被分发到文本控件，
    /// 导致只能通过右键菜单粘贴。菜单本身不会显示在屏幕上，但快捷键会生效。
    private static func buildMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // App 菜单
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenuItem.submenu = appMenu
        appMenu.addItem(withTitle: "退出 SnapAI",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")

        // 编辑菜单（提供标准的剪切/拷贝/粘贴/全选/撤销快捷键）
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "编辑")
        editMenuItem.submenu = editMenu

        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redoItem = editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        return mainMenu
    }

    private func startSelfMonitor() {
        selfMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshSelfMonitor()
            }
        }
    }

    @MainActor
    private func refreshSelfMonitor() {
        let popover = PopoverManager.shared
        let pid = getpid()
        var kinfo = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        let result = sysctl(&mib, UInt32(mib.count), &kinfo, &size, nil, 0)
        if result == 0 {
            let usagePercent = Double(kinfo.kp_proc.p_pctcpu) / Double(0x7fff) * 100.0
            popover.selfCpuUsage = max(0, usagePercent)
        }
        var info = task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_basic_info>.stride / MemoryLayout<integer_t>.stride
        )
        let memResult = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        if memResult == KERN_SUCCESS {
            let residentMB = Double(info.resident_size) / 1_048_576.0
            popover.selfMemoryMB = residentMB
        }
    }
}
