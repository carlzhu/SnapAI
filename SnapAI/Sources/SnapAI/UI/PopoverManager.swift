import AppKit
import SwiftUI

@MainActor
final class PopoverManager: NSObject, NSPopoverDelegate {
    static let shared = PopoverManager()
    let popover: NSPopover
    let categoryStore = CategoryStore.shared
    let historyStore = HistoryStore.shared
    @Published var selfCpuUsage: Double = 0
    @Published var selfMemoryMB: Double = 0
    private var outsideClickMonitor: Any?

    private override init() {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        let hostingController = NSHostingController(
            rootView: AITaskView()
                .environmentObject(categoryStore)
                .environmentObject(historyStore)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
        self.popover = popover
        super.init()
        popover.delegate = self
    }

    func toggle(from button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
            startOutsideClickMonitor()
        }
    }

    func close() {
        if popover.isShown { popover.performClose(nil) }
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            Task { @MainActor in self?.close() }
        }
    }

    private func stopOutsideClickMonitor() {
        if let monitor = outsideClickMonitor {
            NSEvent.removeMonitor(monitor)
            outsideClickMonitor = nil
        }
    }

    func popoverDidClose(_ notification: Notification) { stopOutsideClickMonitor() }
}
