import AppKit
import KeyboardShortcuts

final class StatusBarController: NSObject, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private let windowManager = WindowManager.shared
    private var accessibilityMenuItem: NSMenuItem?
    private var shortcutMenuItems: [(NSMenuItem, KeyboardShortcuts.Name)] = []

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

        menu.addItem(createMenuItem(title: "Move to Left Monitor", action: #selector(moveMonitorLeft), shortcut: .moveMonitorLeft))
        menu.addItem(createMenuItem(title: "Move to Right Monitor", action: #selector(moveMonitorRight), shortcut: .moveMonitorRight))
        menu.addItem(createMenuItem(title: "Move to Upper Monitor", action: #selector(moveMonitorUp), shortcut: .moveMonitorUp))
        menu.addItem(createMenuItem(title: "Move to Lower Monitor", action: #selector(moveMonitorDown), shortcut: .moveMonitorDown))

        menu.addItem(NSMenuItem.separator())

        // Accessibility status (will be updated dynamically)
        let accessibilityItem = NSMenuItem(title: accessibilityStatusText, action: #selector(openAccessibilitySettings), keyEquivalent: "")
        accessibilityItem.target = self
        self.accessibilityMenuItem = accessibilityItem
        menu.addItem(accessibilityItem)

        menu.addItem(NSMenuItem.separator())

        // Preferences
        let preferencesItem = NSMenuItem(title: "Preferences...", action: #selector(openPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)

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

        // Refresh shortcut key equivalents (may have changed in preferences)
        for (item, name) in shortcutMenuItems {
            if let shortcut = KeyboardShortcuts.getShortcut(for: name) {
                item.keyEquivalentModifierMask = shortcut.modifiers
                if let key = shortcut.key {
                    item.keyEquivalent = keyEquivalentString(for: key)
                } else {
                    item.keyEquivalent = ""
                }
            } else {
                item.keyEquivalent = ""
                item.keyEquivalentModifierMask = []
            }
        }
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

        shortcutMenuItems.append((item, shortcut))
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
        case .space: return " "
        case .tab: return "\t"
        case .escape: return String(UnicodeScalar(0x1B))
        case .a: return "a"
        case .b: return "b"
        case .c: return "c"
        case .d: return "d"
        case .e: return "e"
        case .f: return "f"
        case .g: return "g"
        case .h: return "h"
        case .i: return "i"
        case .j: return "j"
        case .k: return "k"
        case .l: return "l"
        case .m: return "m"
        case .n: return "n"
        case .o: return "o"
        case .p: return "p"
        case .q: return "q"
        case .r: return "r"
        case .s: return "s"
        case .t: return "t"
        case .u: return "u"
        case .v: return "v"
        case .w: return "w"
        case .x: return "x"
        case .y: return "y"
        case .z: return "z"
        case .zero: return "0"
        case .one: return "1"
        case .two: return "2"
        case .three: return "3"
        case .four: return "4"
        case .five: return "5"
        case .six: return "6"
        case .seven: return "7"
        case .eight: return "8"
        case .nine: return "9"
        case .f1: return String(UnicodeScalar(NSF1FunctionKey)!)
        case .f2: return String(UnicodeScalar(NSF2FunctionKey)!)
        case .f3: return String(UnicodeScalar(NSF3FunctionKey)!)
        case .f4: return String(UnicodeScalar(NSF4FunctionKey)!)
        case .f5: return String(UnicodeScalar(NSF5FunctionKey)!)
        case .f6: return String(UnicodeScalar(NSF6FunctionKey)!)
        case .f7: return String(UnicodeScalar(NSF7FunctionKey)!)
        case .f8: return String(UnicodeScalar(NSF8FunctionKey)!)
        case .f9: return String(UnicodeScalar(NSF9FunctionKey)!)
        case .f10: return String(UnicodeScalar(NSF10FunctionKey)!)
        case .f11: return String(UnicodeScalar(NSF11FunctionKey)!)
        case .f12: return String(UnicodeScalar(NSF12FunctionKey)!)
        default: return ""
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

    @objc private func moveMonitorLeft() {
        windowManager.moveToMonitor(.left)
    }

    @objc private func moveMonitorRight() {
        windowManager.moveToMonitor(.right)
    }

    @objc private func moveMonitorUp() {
        windowManager.moveToMonitor(.up)
    }

    @objc private func moveMonitorDown() {
        windowManager.moveToMonitor(.down)
    }

    @objc private func openAccessibilitySettings() {
        AccessibilityPermissions.openSystemPreferences()
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.showPreferences()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
