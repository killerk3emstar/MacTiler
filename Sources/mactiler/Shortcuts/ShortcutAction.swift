import AppKit
import KeyboardShortcuts
import MacTilerCore

/// Every user-triggerable action. Hotkeys and the menu bar menu are both
/// built from this list, so adding an action means adding one case here.
@MainActor
enum ShortcutAction: String, CaseIterable {
    case snapLeft, snapRight, snapUp, snapDown
    case maximize, restore, center
    case moveMonitorLeft, moveMonitorRight, moveMonitorUp, moveMonitorDown

    var title: String {
        switch self {
        case .snapLeft: return "Snap Left"
        case .snapRight: return "Snap Right"
        case .snapUp: return "Snap Up"
        case .snapDown: return "Snap Down"
        case .maximize: return "Maximize"
        case .restore: return "Restore"
        case .center: return "Center"
        case .moveMonitorLeft: return "Move to Left Monitor"
        case .moveMonitorRight: return "Move to Right Monitor"
        case .moveMonitorUp: return "Move to Upper Monitor"
        case .moveMonitorDown: return "Move to Lower Monitor"
        }
    }

    /// Menu sections, in display order.
    static let menuGroups: [[ShortcutAction]] = [
        [.snapLeft, .snapRight, .snapUp, .snapDown],
        [.maximize, .restore, .center],
        [.moveMonitorLeft, .moveMonitorRight, .moveMonitorUp, .moveMonitorDown],
    ]

    var name: KeyboardShortcuts.Name {
        KeyboardShortcuts.Name(rawValue)
    }

    func perform() {
        let manager = WindowManager.shared
        switch self {
        case .snapLeft: manager.handleDirection(.left)
        case .snapRight: manager.handleDirection(.right)
        case .snapUp: manager.handleDirection(.up)
        case .snapDown: manager.handleDirection(.down)
        case .maximize: manager.maximize()
        case .restore: manager.restore()
        case .center: manager.center()
        case .moveMonitorLeft: manager.moveToMonitor(.left)
        case .moveMonitorRight: manager.moveToMonitor(.right)
        case .moveMonitorUp: manager.moveToMonitor(.up)
        case .moveMonitorDown: manager.moveToMonitor(.down)
        }
    }

    /// The shortcut this action should have according to Settings.
    func shortcut(from settings: Settings) -> KeyboardShortcuts.Shortcut {
        let key: KeyboardShortcuts.Key
        let modifiers: NSEvent.ModifierFlags
        switch self {
        case .snapLeft: (key, modifiers) = (.leftArrow, settings.tilingModifiers)
        case .snapRight: (key, modifiers) = (.rightArrow, settings.tilingModifiers)
        case .snapUp: (key, modifiers) = (.upArrow, settings.tilingModifiers)
        case .snapDown: (key, modifiers) = (.downArrow, settings.tilingModifiers)
        case .maximize: (key, modifiers) = (.init(rawValue: settings.maximizeKey), settings.tilingModifiers)
        case .restore: (key, modifiers) = (.init(rawValue: settings.restoreKey), settings.tilingModifiers)
        case .center: (key, modifiers) = (.init(rawValue: settings.centerKey), settings.tilingModifiers)
        case .moveMonitorLeft: (key, modifiers) = (.leftArrow, settings.monitorModifiers)
        case .moveMonitorRight: (key, modifiers) = (.rightArrow, settings.monitorModifiers)
        case .moveMonitorUp: (key, modifiers) = (.upArrow, settings.monitorModifiers)
        case .moveMonitorDown: (key, modifiers) = (.downArrow, settings.monitorModifiers)
        }
        return KeyboardShortcuts.Shortcut(key, modifiers: modifiers)
    }

    // MARK: - Registration

    /// Registers key-down handlers for all actions and applies current Settings.
    static func registerAll() {
        for action in allCases {
            KeyboardShortcuts.onKeyDown(for: action.name) { action.perform() }
        }
        syncWithSettings()
    }

    /// Pushes Settings into KeyboardShortcuts. Settings owns the shortcuts;
    /// KeyboardShortcuts' own storage is only a mirror used for registration.
    static func syncWithSettings() {
        let settings = Settings.shared
        for action in allCases {
            let desired = action.shortcut(from: settings)
            if KeyboardShortcuts.getShortcut(for: action.name) != desired {
                KeyboardShortcuts.setShortcut(desired, for: action.name)
            }
        }
    }

    static func setEnabled(_ enabled: Bool) {
        let names = allCases.map(\.name)
        if enabled {
            KeyboardShortcuts.enable(names)
        } else {
            KeyboardShortcuts.disable(names)
        }
    }
}
