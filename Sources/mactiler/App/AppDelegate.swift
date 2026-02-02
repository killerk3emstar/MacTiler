import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let shortcutManager = ShortcutManager.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        Logger.log("MacTiler starting...")

        checkAccessibilityPermissions()

        statusBarController = StatusBarController()
        statusBarController?.setup()
        Logger.log("Status bar ready")

        shortcutManager.setupShortcuts()

        WindowManager.shared.setupDragDetection()

        Logger.success("MacTiler ready!")
    }

    func applicationWillTerminate(_ notification: Notification) {
        Logger.log("MacTiler shutting down")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    private func checkAccessibilityPermissions() {
        if AccessibilityPermissions.isGranted {
            Logger.success("Accessibility: granted")
        } else {
            Logger.error("Accessibility: NOT granted - requesting...")
            AccessibilityPermissions.requestPermissions()
        }
    }
}
