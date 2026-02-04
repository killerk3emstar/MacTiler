import Foundation
import ServiceManagement

final class Settings {
    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let windowGap = "windowGap"
        static let launchAtLogin = "launchAtLogin"
        static let showInMenuBar = "showInMenuBar"
        static let minimizeEnabled = "minimizeEnabled"
        static let restoreSizeOnUntile = "restoreSizeOnUntile"
        static let animationsEnabled = "animationsEnabled"
    }

    private init() {}

    var windowGap: CGFloat {
        get { CGFloat(defaults.double(forKey: Keys.windowGap)) }
        set {
            defaults.set(Double(newValue), forKey: Keys.windowGap)
            NotificationCenter.default.post(name: .settingsChanged, object: nil)
        }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            updateLaunchAtLogin(newValue)
        }
    }

    var showInMenuBar: Bool {
        get { defaults.object(forKey: Keys.showInMenuBar) == nil ? true : defaults.bool(forKey: Keys.showInMenuBar) }
        set { defaults.set(newValue, forKey: Keys.showInMenuBar) }
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

    private func updateLaunchAtLogin(_ enabled: Bool) {
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

extension Notification.Name {
    static let settingsChanged = Notification.Name("settingsChanged")
}
