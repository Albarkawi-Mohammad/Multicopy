import Foundation

final class PanelModel: ObservableObject {
    @Published var query = ""
    @Published var selectedID: UUID?
    @Published var focusRequest = 0
    @Published var accessibilityGranted = Permissions.isAccessibilityGranted
    @Published var launchAtLogin = LaunchAtLogin.isEnabled

    func prepareForShow() {
        query = ""
        selectedID = nil
        accessibilityGranted = Permissions.isAccessibilityGranted
        launchAtLogin = LaunchAtLogin.isEnabled
    }

    func requestFocus() {
        focusRequest += 1
    }
}
