import AppKit
import SwiftUI
import MulticopyCore

final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController {
    private let store: ClipboardStore
    private let model = PanelModel()
    private var panel: FloatingPanel?
    private var keyMonitor: Any?
    private var lastExternalApp: NSRunningApplication?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(store: ClipboardStore) {
        self.store = store
        recordFrontmostApp()

        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(workspaceDidActivateApplication(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidResignActive),
            name: NSApplication.didResignActiveNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }

    deinit {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
        }
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        NotificationCenter.default.removeObserver(self)
    }

    func toggle() {
        if isVisible {
            hide(restoreFocus: true)
        } else {
            show()
        }
    }

    func show() {
        recordFrontmostApp()
        model.prepareForShow()

        let panel = makePanelIfNeeded()
        position(panel)

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyMonitor()

        DispatchQueue.main.async { [weak self] in
            self?.model.requestFocus()
        }
    }

    func hide(restoreFocus: Bool = false) {
        removeKeyMonitor()
        panel?.orderOut(nil)

        if restoreFocus,
           let app = lastExternalApp,
           app != NSRunningApplication.current {
            app.activate(options: [.activateAllWindows])
        }
    }

    func clearHistory() {
        let wasVisible = isVisible
        hide()

        let alert = NSAlert()
        alert.messageText = "Clear history?"
        alert.informativeText = "All unpinned copies will be removed. Pinned copies are kept."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            store.clearUnpinned()
            model.selectedID = nil
        }

        if wasVisible {
            show()
        }
    }

    private func makePanelIfNeeded() -> FloatingPanel {
        if let panel {
            return panel
        }

        let rootView = HistoryView(
            store: store,
            model: model,
            onPaste: { [weak self] item in self?.paste(item) },
            onCopy: { [weak self] item in self?.copy(item) },
            onTogglePin: { [weak self] id in self?.store.togglePin(id) },
            onDelete: { [weak self] id in self?.delete(id) },
            onClose: { [weak self] in self?.hide(restoreFocus: true) },
            onEnableAutoPaste: { [weak self] in self?.enableAutoPaste() },
            onToggleLaunchAtLogin: { [weak self] enabled in self?.setLaunchAtLogin(enabled) },
            onClearHistory: { [weak self] in self?.clearHistory() },
            onQuit: { NSApp.terminate(nil) }
        )

        let hostingView = NSHostingView(rootView: rootView)
        let panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 470, height: 544),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.title = "Multicopy"
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.isMovable = false
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = false

        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }

        let originX = (visibleFrame.midX - panel.frame.width / 2).rounded()
        let originY = (visibleFrame.maxY - panel.frame.height - 16).rounded()
        panel.setFrameOrigin(NSPoint(x: originX, y: originY))
    }

    private func installKeyMonitor() {
        removeKeyMonitor()

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyEvent(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.window === panel else { return false }
        let items = store.visibleItems(query: model.query)

        switch event.keyCode {
        case 53:
            hide(restoreFocus: true)
            return true

        case 126:
            moveSelection(by: -1, in: items)
            return true

        case 125:
            moveSelection(by: 1, in: items)
            return true

        case 36, 76:
            if let id = highlightedID(in: items),
               let item = items.first(where: { $0.id == id }) {
                paste(item)
            }
            return true

        case 51, 117:
            if event.modifierFlags.contains(.command) {
                if let id = highlightedID(in: items) {
                    delete(id)
                }
                return true
            }
            return false

        default:
            return false
        }
    }

    private func highlightedID(in items: [ClipboardStore.Item]) -> UUID? {
        if let id = model.selectedID, items.contains(where: { $0.id == id }) {
            return id
        }
        return items.first?.id
    }

    private func moveSelection(by offset: Int, in items: [ClipboardStore.Item]) {
        guard !items.isEmpty else { return }

        let current = highlightedID(in: items)
        let index = items.firstIndex(where: { $0.id == current }) ?? 0
        let nextIndex = min(max(index + offset, 0), items.count - 1)
        model.selectedID = items[nextIndex].id
    }

    private func paste(_ item: ClipboardStore.Item) {
        let target = lastExternalApp
        let canAutoPaste = Permissions.isAccessibilityGranted
        store.copyToPasteboard(item)
        hide()

        guard let target,
              target.bundleIdentifier != Bundle.main.bundleIdentifier else {
            ToastController.shared.show(
                title: "Copied to clipboard",
                message: "Press \u{2318}V to paste."
            )
            return
        }

        let activated = target.activate(options: [.activateAllWindows])

        guard canAutoPaste else {
            ToastController.shared.show(
                title: "Copied to clipboard",
                message: "Press \u{2318}V, or enable auto-paste in Settings."
            )
            return
        }

        guard activated else {
            ToastController.shared.show(
                title: "Copied to clipboard",
                message: "Press \u{2318}V to paste."
            )
            return
        }

        pasteWhenReady(target: target, attempts: 0)
    }

    private func pasteWhenReady(target: NSRunningApplication, attempts: Int) {
        if NSWorkspace.shared.frontmostApplication?.processIdentifier == target.processIdentifier {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                PasteService.pressCommandV()
            }
            return
        }

        guard attempts < 15 else {
            ToastController.shared.show(
                title: "Copied to clipboard",
                message: "Press \u{2318}V to paste."
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.03) { [weak self] in
            self?.pasteWhenReady(target: target, attempts: attempts + 1)
        }
    }

    private func copy(_ item: ClipboardStore.Item) {
        store.copyToPasteboard(item)
    }

    private func delete(_ id: UUID) {
        store.delete(id)
        if model.selectedID == id {
            model.selectedID = nil
        }
    }

    private func enableAutoPaste() {
        Permissions.requestAccessibilityPrompt()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.model.accessibilityGranted = Permissions.isAccessibilityGranted
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            model.launchAtLogin = LaunchAtLogin.isEnabled
        } catch {
            model.launchAtLogin = LaunchAtLogin.isEnabled
            hide()

            let alert = NSAlert()
            alert.messageText = "Could not update login item"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.window.level = .floating
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()

            show()
        }
    }

    private func recordFrontmostApp() {
        guard
            let app = NSWorkspace.shared.frontmostApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier
        else {
            return
        }
        lastExternalApp = app
    }

    @objc private func workspaceDidActivateApplication(_ notification: Notification) {
        guard
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
            app.bundleIdentifier != Bundle.main.bundleIdentifier,
            app.activationPolicy == .regular
        else {
            return
        }
        lastExternalApp = app
    }

    @objc private func appDidResignActive() {
        hide(restoreFocus: false)
    }

    @objc private func appDidBecomeActive() {
        model.accessibilityGranted = Permissions.isAccessibilityGranted
        model.launchAtLogin = LaunchAtLogin.isEnabled
    }
}
