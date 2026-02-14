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
        case .moveMonitorLeft:
            return KeyboardShortcuts.Shortcut(.leftArrow, modifiers: [.control, .command, .option])
        case .moveMonitorRight:
            return KeyboardShortcuts.Shortcut(.rightArrow, modifiers: [.control, .command, .option])
        case .moveMonitorUp:
            return KeyboardShortcuts.Shortcut(.upArrow, modifiers: [.control, .command, .option])
        case .moveMonitorDown:
            return KeyboardShortcuts.Shortcut(.downArrow, modifiers: [.control, .command, .option])
        }
    }
}
