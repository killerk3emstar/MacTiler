import AppKit
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let snapUp = Self("snapUp")
    static let snapDown = Self("snapDown")
    static let snapLeft = Self("snapLeft")
    static let snapRight = Self("snapRight")
    static let maximize = Self("maximize")
    static let restore = Self("restore")
    static let center = Self("center")
    static let moveMonitorLeft = Self("moveMonitorLeft")
    static let moveMonitorRight = Self("moveMonitorRight")
    static let moveMonitorUp = Self("moveMonitorUp")
    static let moveMonitorDown = Self("moveMonitorDown")
}

enum ShortcutGroup {
    case tiling
    case monitor
}

enum ShortcutAction: String, CaseIterable {
    case snapUp
    case snapDown
    case snapLeft
    case snapRight
    case maximize
    case restore
    case center
    case moveMonitorLeft
    case moveMonitorRight
    case moveMonitorUp
    case moveMonitorDown

    var keyboardShortcutName: KeyboardShortcuts.Name {
        switch self {
        case .snapUp: return .snapUp
        case .snapDown: return .snapDown
        case .snapLeft: return .snapLeft
        case .snapRight: return .snapRight
        case .maximize: return .maximize
        case .restore: return .restore
        case .center: return .center
        case .moveMonitorLeft: return .moveMonitorLeft
        case .moveMonitorRight: return .moveMonitorRight
        case .moveMonitorUp: return .moveMonitorUp
        case .moveMonitorDown: return .moveMonitorDown
        }
    }

    var group: ShortcutGroup {
        switch self {
        case .snapUp, .snapDown, .snapLeft, .snapRight,
             .maximize, .restore, .center:
            return .tiling
        case .moveMonitorLeft, .moveMonitorRight,
             .moveMonitorUp, .moveMonitorDown:
            return .monitor
        }
    }

    /// Fixed key for this action (arrow-based shortcuts), nil for configurable keys.
    var fixedKey: KeyboardShortcuts.Key? {
        switch self {
        case .snapUp, .moveMonitorUp: return .upArrow
        case .snapDown, .moveMonitorDown: return .downArrow
        case .snapLeft, .moveMonitorLeft: return .leftArrow
        case .snapRight, .moveMonitorRight: return .rightArrow
        case .maximize, .restore, .center: return nil
        }
    }

    /// Resolve the key for this action from Settings (for configurable keys).
    func resolvedKey(from settings: Settings = .shared) -> KeyboardShortcuts.Key {
        if let fixed = fixedKey { return fixed }
        switch self {
        case .maximize: return KeyboardShortcuts.Key(rawValue: settings.maximizeKey)
        case .restore: return KeyboardShortcuts.Key(rawValue: settings.restoreKey)
        case .center: return KeyboardShortcuts.Key(rawValue: settings.centerKey)
        default: fatalError("Unexpected configurable action: \(self)")
        }
    }

    func resolvedModifiers(from settings: Settings = .shared) -> NSEvent.ModifierFlags {
        switch group {
        case .tiling: return settings.tilingModifiers
        case .monitor: return settings.monitorModifiers
        }
    }

    func resolvedShortcut(from settings: Settings = .shared) -> KeyboardShortcuts.Shortcut {
        KeyboardShortcuts.Shortcut(resolvedKey(from: settings), modifiers: resolvedModifiers(from: settings))
    }
}
