import AppKit
import KeyboardShortcuts

final class ShortcutManager {
    static let shared = ShortcutManager()

    private let windowManager = WindowManager.shared

    private init() {}

    func setupShortcuts() {
        registerDefaultShortcuts()
        setupHandlers()
    }

    private func registerDefaultShortcuts() {
        for action in ShortcutAction.allCases {
            if KeyboardShortcuts.getShortcut(for: action.keyboardShortcutName) == nil {
                if let defaultShortcut = action.defaultShortcut {
                    KeyboardShortcuts.setShortcut(defaultShortcut, for: action.keyboardShortcutName)
                }
            }
        }
    }

    private func setupHandlers() {
        KeyboardShortcuts.onKeyUp(for: .snapUp) { [weak self] in
            self?.windowManager.handleDirection(.up)
        }

        KeyboardShortcuts.onKeyUp(for: .snapDown) { [weak self] in
            self?.windowManager.handleDirection(.down)
        }

        KeyboardShortcuts.onKeyUp(for: .snapLeft) { [weak self] in
            self?.windowManager.handleDirection(.left)
        }

        KeyboardShortcuts.onKeyUp(for: .snapRight) { [weak self] in
            self?.windowManager.handleDirection(.right)
        }

        KeyboardShortcuts.onKeyUp(for: .maximize) { [weak self] in
            self?.windowManager.maximize()
        }

        KeyboardShortcuts.onKeyUp(for: .restore) { [weak self] in
            self?.windowManager.restore()
        }

        KeyboardShortcuts.onKeyUp(for: .center) { [weak self] in
            self?.windowManager.center()
        }

        KeyboardShortcuts.onKeyUp(for: .moveMonitorLeft) { [weak self] in
            self?.windowManager.moveToMonitor(.left)
        }

        KeyboardShortcuts.onKeyUp(for: .moveMonitorRight) { [weak self] in
            self?.windowManager.moveToMonitor(.right)
        }

        KeyboardShortcuts.onKeyUp(for: .moveMonitorUp) { [weak self] in
            self?.windowManager.moveToMonitor(.up)
        }

        KeyboardShortcuts.onKeyUp(for: .moveMonitorDown) { [weak self] in
            self?.windowManager.moveToMonitor(.down)
        }
    }
}
