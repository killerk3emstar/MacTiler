import AppKit
import ApplicationServices

enum AccessibilityPermissions {
    static var isGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSystemPreferences() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

}
