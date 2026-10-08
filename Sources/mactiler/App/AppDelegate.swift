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

    /// Launching MacTiler again while it runs (Spotlight, Finder, Raycast)
    /// opens Preferences. This is the way back in when the menu bar icon is
    /// hidden, either by our setting or by macOS menu bar management.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        PreferencesWindowController.shared.showPreferences()
        return false
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}
