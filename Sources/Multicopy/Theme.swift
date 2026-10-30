import AppKit
import SwiftUI

enum Brand {
    static let accent = Color(
        nsColor: NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua {
                return NSColor(srgbRed: 1.00, green: 0.52, blue: 0.36, alpha: 1)
            }
            return NSColor(srgbRed: 0.88, green: 0.29, blue: 0.14, alpha: 1)
        }
    )
}

extension Date {
    private static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }()

    var shortRelativeDescription: String {
        let seconds = max(0, Int(Date().timeIntervalSince(self)))

        if seconds < 10 { return "now" }
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3_600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3_600)h" }
        if seconds < 604_800 { return "\(seconds / 86_400)d" }
        return Self.shortDateFormatter.string(from: self)
    }
}
