import AppKit
import ApplicationServices

enum AccessibilityPermissions {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermissions() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    @MainActor
    static func openSystemSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
