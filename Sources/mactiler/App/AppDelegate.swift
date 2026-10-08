import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("MacTiler starting")

        // Global cap for AX calls into other apps. AXWindow sets tighter
        // per-window timeouts on top of this.
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.0)

        if !AccessibilityPermissions.isGranted {
            Log.error("Accessibility not granted, requesting")
            AccessibilityPermissions.requestPermissions()
        }

        ShortcutAction.registerAll()
        WindowManager.shared.start()

        let statusBar = StatusBarController()
        statusBar.setup()
        statusBarController = statusBar

        Log.info("MacTiler ready")
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
