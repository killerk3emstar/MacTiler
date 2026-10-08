import AppKit
import KeyboardShortcuts

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var accessibilityItem: NSMenuItem?

    func setup() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "MacTiler")
        item.menu = makeMenu()
        statusItem = item
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        for group in ShortcutAction.menuGroups {
            for action in group {
                let item = NSMenuItem(title: action.title, action: #selector(performAction(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = action.rawValue
                item.setShortcut(for: action.name) // stays in sync when shortcuts change
                menu.addItem(item)
            }
            menu.addItem(.separator())
        }

        let accessibilityItem = NSMenuItem(title: "", action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        menu.addItem(accessibilityItem)
        self.accessibilityItem = accessibilityItem
        updateAccessibilityItem()

        menu.addItem(.separator())

        let preferences = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        preferences.target = self
        menu.addItem(preferences)

        let quit = NSMenuItem(title: "Quit MacTiler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        updateAccessibilityItem()
        // Global hotkeys get buffered while a menu tracks and fire on close. Pause them.
        ShortcutAction.setEnabled(false)
    }

    func menuDidClose(_ menu: NSMenu) {
        ShortcutAction.setEnabled(true)
    }

    private func updateAccessibilityItem() {
        accessibilityItem?.title = AccessibilityPermissions.isGranted
            ? "Accessibility: Granted"
            : "Accessibility: Not Granted (Click to fix)"
    }

    // MARK: - Actions

    @objc private func performAction(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let action = ShortcutAction(rawValue: raw) else { return }
        action.perform()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermissions.openSystemSettings()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.showPreferences()
    }
}
