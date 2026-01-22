import AppKit
import KeyboardShortcuts

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let windowManager = WindowManager.shared
    private var accessibilityMenuItem: NSMenuItem?

    func setup() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.split.2x2", accessibilityDescription: "MacTiler")
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.delegate = self

        // Snap actions
        menu.addItem(createMenuItem(title: "Snap Left", action: #selector(snapLeft), shortcut: .snapLeft))
        menu.addItem(createMenuItem(title: "Snap Right", action: #selector(snapRight), shortcut: .snapRight))
        menu.addItem(createMenuItem(title: "Snap Up", action: #selector(snapUp), shortcut: .snapUp))
        menu.addItem(createMenuItem(title: "Snap Down", action: #selector(snapDown), shortcut: .snapDown))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(createMenuItem(title: "Maximize", action: #selector(maximize), shortcut: .maximize))
        menu.addItem(createMenuItem(title: "Restore", action: #selector(restore), shortcut: .restore))
        menu.addItem(createMenuItem(title: "Center", action: #selector(center), shortcut: .center))

        menu.addItem(NSMenuItem.separator())

        // Accessibility status (will be updated dynamically)
        let accessibilityItem = NSMenuItem(title: accessibilityStatusText, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        self.accessibilityMenuItem = accessibilityItem
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MacTiler", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - NSMenuDelegate

    func menuWillOpen(_ menu: NSMenu) {
        // Update accessibility status each time menu opens
        accessibilityMenuItem?.title = accessibilityStatusText
    }

    private func createMenuItem(title: String, action: Selector, shortcut: KeyboardShortcuts.Name) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self

        if let shortcut = KeyboardShortcuts.getShortcut(for: shortcut) {
            item.keyEquivalentModifierMask = shortcut.modifiers
            if let key = shortcut.key {
                item.keyEquivalent = keyEquivalentString(for: key)
            }
        }

        return item
    }

    private func keyEquivalentString(for key: KeyboardShortcuts.Key) -> String {
        switch key {
        case .upArrow: return String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case .downArrow: return String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case .leftArrow: return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case .rightArrow: return String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case .return: return "\r"
        case .delete: return String(UnicodeScalar(NSDeleteCharacter)!)
        case .c: return "c"
        default:
            if let scalar = UnicodeScalar(key.rawValue) {
                return String(scalar)
            }
            return ""
        }
    }

    private var accessibilityStatusText: String {
        AccessibilityPermissions.isGranted ? "Accessibility: Granted" : "Accessibility: Not Granted (Click to fix)"
    }

    @objc private func snapLeft() {
        windowManager.handleDirection(.left)
    }

    @objc private func snapRight() {
        windowManager.handleDirection(.right)
    }

    @objc private func snapUp() {
        windowManager.handleDirection(.up)
    }

    @objc private func snapDown() {
        windowManager.handleDirection(.down)
    }

    @objc private func maximize() {
        windowManager.maximize()
    }

    @objc private func restore() {
        windowManager.restore()
    }

    @objc private func center() {
        windowManager.center()
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermissions.openSystemPreferences()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
