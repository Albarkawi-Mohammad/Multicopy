import AppKit
import MulticopyCore

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = ClipboardStore()
    private let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var panelController: PanelController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = PanelController(store: store)
        setUpStatusItem()
        store.startMonitoring()

        hotKeyManager.register { [weak self] in
            self?.panelController.toggle()
        }

        if CommandLine.arguments.contains("--show-panel") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.panelController.show()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        store.stopMonitoring()
        store.saveNow()
        hotKeyManager.unregister()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panelController.show()
        return false
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if let openItem = menu.items.first {
            openItem.title = panelController.isVisible ? "Hide Multicopy" : "Open Multicopy"
        }

        if let launchItem = menu.item(withTag: 100) {
            launchItem.state = LaunchAtLogin.isEnabled ? .on : .off
        }

        if let accessItem = menu.item(withTag: 101) {
            let granted = Permissions.isAccessibilityGranted
            accessItem.title = granted ? "Auto-Paste Enabled" : "Enable Auto-Paste\u{2026}"
            accessItem.isEnabled = !granted
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            panelController.toggle()
        }
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            try LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
        } catch {
            presentError(error)
        }
    }

    @objc private func enableAutoPaste() {
        Permissions.requestAccessibilityPrompt()
    }

    @objc private func clearHistory() {
        panelController.clearHistory()
    }

    private func setUpStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            let image = NSImage(
                systemSymbolName: "doc.on.clipboard",
                accessibilityDescription: "Multicopy"
            )
            image?.isTemplate = true
            button.image = image
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Multicopy \u{2014} \u{2318}\u{21E7}V"
        }

        menu = makeMenu()
        menu.delegate = self
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let openItem = NSMenuItem(
            title: "Open Multicopy",
            action: #selector(togglePanel),
            keyEquivalent: "v"
        )
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())

        let launchItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchItem.target = self
        launchItem.tag = 100
        menu.addItem(launchItem)

        let accessItem = NSMenuItem(
            title: "Enable Auto-Paste\u{2026}",
            action: #selector(enableAutoPaste),
            keyEquivalent: ""
        )
        accessItem.target = self
        accessItem.tag = 101
        menu.addItem(accessItem)

        menu.addItem(.separator())

        let clearItem = NSMenuItem(
            title: "Clear Unpinned History\u{2026}",
            action: #selector(clearHistory),
            keyEquivalent: ""
        )
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Multicopy",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quitItem)

        return menu
    }

    private func presentError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Could not update login item"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}
