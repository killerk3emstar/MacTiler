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

    static func checkAndRequestIfNeeded(completion: @escaping (Bool) -> Void) {
        if isGranted {
            completion(true)
            return
        }

        requestPermissions()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            pollForPermission(attempts: 30, completion: completion)
        }
    }

    private static func pollForPermission(attempts: Int, completion: @escaping (Bool) -> Void) {
        guard attempts > 0 else {
            completion(false)
            return
        }

        if isGranted {
            completion(true)
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            pollForPermission(attempts: attempts - 1, completion: completion)
        }
    }
}
