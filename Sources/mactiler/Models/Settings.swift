import AppKit
import Carbon.HIToolbox
import ServiceManagement

final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let windowGap = "windowGap"
        static let launchAtLogin = "launchAtLogin"
        static let minimizeEnabled = "minimizeEnabled"
        static let restoreSizeOnUntile = "restoreSizeOnUntile"
        static let animationsEnabled = "animationsEnabled"
        static let tilingModifiers = "tilingModifiers"
        static let monitorModifiers = "monitorModifiers"
        static let maximizeKey = "maximizeKey"
        static let restoreKey = "restoreKey"
        static let centerKey = "centerKey"
    }

    private init() {}

    var windowGap: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.windowGap)) }
        set { defaults.set(Double(newValue), forKey: Keys.windowGap) }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(newValue)
        }
    }

    var minimizeEnabled: Bool {
        get { defaults.object(forKey: Keys.minimizeEnabled) == nil ? true : defaults.bool(forKey: Keys.minimizeEnabled) }
        set { defaults.set(newValue, forKey: Keys.minimizeEnabled) }
    }

    var restoreSizeOnUntile: Bool {
        get { defaults.bool(forKey: Keys.restoreSizeOnUntile) }
        set { defaults.set(newValue, forKey: Keys.restoreSizeOnUntile) }
    }

    var animationsEnabled: Bool {
        get { defaults.object(forKey: Keys.animationsEnabled) == nil ? true : defaults.bool(forKey: Keys.animationsEnabled) }
        set { defaults.set(newValue, forKey: Keys.animationsEnabled) }
    }

    // MARK: - Shortcut modifier groups

    // Stored as carbon Int for reliable UserDefaults round-trip.
    // cmdKey=256, optionKey=2048, controlKey=4096, shiftKey=512
    private static let defaultTilingCarbon = cmdKey | optionKey           // 2304
    private static let defaultMonitorCarbon = controlKey | cmdKey | optionKey  // 6400

    var tilingModifiers: NSEvent.ModifierFlags {
        get {
            let carbon = defaults.object(forKey: Keys.tilingModifiers) as? Int ?? Settings.defaultTilingCarbon
            return Self.carbonToModifiers(carbon)
        }
        set { defaults.set(Self.modifiersToCarbon(newValue), forKey: Keys.tilingModifiers) }
    }

    var monitorModifiers: NSEvent.ModifierFlags {
        get {
            let carbon = defaults.object(forKey: Keys.monitorModifiers) as? Int ?? Settings.defaultMonitorCarbon
            return Self.carbonToModifiers(carbon)
        }
        set { defaults.set(Self.modifiersToCarbon(newValue), forKey: Keys.monitorModifiers) }
    }

    // Key raw values (Carbon key codes)
    // Default: Return = 36, Delete = 51, C = 8
    var maximizeKey: Int {
        get { defaults.object(forKey: Keys.maximizeKey) as? Int ?? kVK_Return }
        set { defaults.set(newValue, forKey: Keys.maximizeKey) }
    }

    var restoreKey: Int {
        get { defaults.object(forKey: Keys.restoreKey) as? Int ?? kVK_Delete }
        set { defaults.set(newValue, forKey: Keys.restoreKey) }
    }

    var centerKey: Int {
        get { defaults.object(forKey: Keys.centerKey) as? Int ?? kVK_ANSI_C }
        set { defaults.set(newValue, forKey: Keys.centerKey) }
    }

    // MARK: - Carbon ↔ NSEvent.ModifierFlags conversion

    static func modifiersToCarbon(_ flags: NSEvent.ModifierFlags) -> Int {
        var carbon = 0
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        if flags.contains(.command) { carbon |= cmdKey }
        return carbon
    }

    static func carbonToModifiers(_ carbon: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & controlKey == controlKey { flags.insert(.control) }
        if carbon & optionKey == optionKey { flags.insert(.option) }
        if carbon & shiftKey == shiftKey { flags.insert(.shift) }
        if carbon & cmdKey == cmdKey { flags.insert(.command) }
        return flags
    }

    func updateLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Logger.error("Failed to update launch at login: \(error)")
        }
    }
}
