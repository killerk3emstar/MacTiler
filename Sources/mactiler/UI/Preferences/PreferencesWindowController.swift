import AppKit
import SwiftUI

/// Owns the Preferences window.
///
/// MacTiler normally runs as an accessory app: no Dock icon and no main menu.
/// An accessory app that becomes active with no menu leaves the menu bar
/// empty, so while Preferences is open the app switches to a regular app with
/// its own menu, Dock icon and Cmd-Tab entry, and switches back on close.
@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func showPreferences() {
        let window = self.window ?? makeWindow()
        self.window = window

        NSApp.setActivationPolicy(.regular)
        NSApp.mainMenu = Self.makeMainMenu()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    private func makeWindow() -> NSWindow {
        // Toolbar-style tabs are the native preferences layout. On macOS 26+
        // the same window automatically gets the Liquid Glass look.
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("General", symbol: "gearshape", GeneralSettingsView()))
        tabs.addTabViewItem(Self.tab("Shortcuts", symbol: "keyboard", ShortcutsSettingsView()))
        tabs.addTabViewItem(Self.tab("About", symbol: "info.circle", AboutView()))

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable, .resizable]
        window.toolbarStyle = .preference
        window.contentMinSize = NSSize(width: 380, height: 300)
        window.setContentSize(NSSize(width: 480, height: 540))
        // Open on the Space the user is on instead of jumping to the one it was first shown on
        window.collectionBehavior = [.moveToActiveSpace]
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        return window
    }

    private static func tab(_ title: String, symbol: String, _ view: some View) -> NSTabViewItem {
        let controller = NSHostingController(rootView: view)
        // Let the window keep its size when switching tabs instead of snapping to each view's ideal size
        controller.sizingOptions = []
        controller.title = title
        let item = NSTabViewItem(viewController: controller)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }

    private static func makeMainMenu() -> NSMenu {
        let main = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About MacTiler", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide MacTiler", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit MacTiler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(submenu: appMenu, title: "MacTiler")

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        main.addItem(submenu: editMenu, title: "Edit")

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        main.addItem(submenu: windowMenu, title: "Window")

        return main
    }
}

private extension NSMenu {
    func addItem(submenu: NSMenu, title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.submenu = submenu
        addItem(item)
    }
}
