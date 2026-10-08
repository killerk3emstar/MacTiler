import AppKit
import SwiftUI

@MainActor
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func showPreferences() {
        if window == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: PreferencesView()))
            window.title = "MacTiler Preferences"
            window.styleMask = [.titled, .closable, .resizable]
            window.contentMinSize = NSSize(width: 460, height: 380)
            window.center()
            window.setFrameAutosaveName("PreferencesWindow")
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}
