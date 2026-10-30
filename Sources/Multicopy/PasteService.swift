import Carbon
import Foundation

enum PasteService {
    static func pressCommandV() {
        guard Permissions.isAccessibilityGranted else { return }
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }

        let keyCode = CGKeyCode(kVK_ANSI_V)

        if let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true) {
            keyDown.flags = .maskCommand
            keyDown.post(tap: .cghidEventTap)
        }

        Thread.sleep(forTimeInterval: 0.012)

        if let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) {
            keyUp.flags = .maskCommand
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
