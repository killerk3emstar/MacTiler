import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static let snapUp = Self("snapUp")
    static let snapDown = Self("snapDown")
    static let snapLeft = Self("snapLeft")
    static let snapRight = Self("snapRight")
    static let maximize = Self("maximize")
    static let restore = Self("restore")
    static let center = Self("center")
}

enum ShortcutAction: String, CaseIterable {
    case snapUp
    case snapDown
    case snapLeft
    case snapRight
    case maximize
    case restore
    case center

    var keyboardShortcutName: KeyboardShortcuts.Name {
        switch self {
        case .snapUp: return .snapUp
        case .snapDown: return .snapDown
        case .snapLeft: return .snapLeft
        case .snapRight: return .snapRight
        case .maximize: return .maximize
        case .restore: return .restore
        case .center: return .center
        }
    }

    var displayName: String {
        switch self {
        case .snapUp: return "Snap Up"
        case .snapDown: return "Snap Down"
        case .snapLeft: return "Snap Left"
        case .snapRight: return "Snap Right"
        case .maximize: return "Maximize"
        case .restore: return "Restore"
        case .center: return "Center"
        }
    }

    var defaultShortcut: KeyboardShortcuts.Shortcut? {
        switch self {
        case .snapUp:
            return KeyboardShortcuts.Shortcut(.upArrow, modifiers: [.command, .option])
        case .snapDown:
            return KeyboardShortcuts.Shortcut(.downArrow, modifiers: [.command, .option])
        case .snapLeft:
            return KeyboardShortcuts.Shortcut(.leftArrow, modifiers: [.command, .option])
        case .snapRight:
            return KeyboardShortcuts.Shortcut(.rightArrow, modifiers: [.command, .option])
        case .maximize:
            return KeyboardShortcuts.Shortcut(.return, modifiers: [.command, .option])
        case .restore:
            return KeyboardShortcuts.Shortcut(.delete, modifiers: [.command, .option])
        case .center:
            return KeyboardShortcuts.Shortcut(.c, modifiers: [.command, .option])
        }
    }
}
