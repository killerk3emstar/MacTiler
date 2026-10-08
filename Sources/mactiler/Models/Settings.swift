import AppKit
import Carbon.HIToolbox
import MacTilerCore
import Observation
import ServiceManagement

/// The single source of truth for preferences. Every property persists to
/// UserDefaults on write; the Preferences window binds to it directly.
@MainActor
@Observable
final class Settings {
    static let shared = Settings()

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Key: String {
        case windowGap, minimizeEnabled, restoreSizeOnUntile, animationsEnabled, showMenuBarIcon, resizeAnimation, overlayStyle
        case tilingModifiers, monitorModifiers, maximizeKey, restoreKey, centerKey
        case fractionQuarter, fractionThird, fractionTwoThirds, fractionThreeQuarters
    }

    var windowGap: CGFloat { didSet { save(Double(windowGap), .windowGap) } }
    var minimizeEnabled: Bool { didSet { save(minimizeEnabled, .minimizeEnabled) } }
    var restoreSizeOnUntile: Bool { didSet { save(restoreSizeOnUntile, .restoreSizeOnUntile) } }
    var animationsEnabled: Bool { didSet { save(animationsEnabled, .animationsEnabled) } }
    /// How size changes are animated. Pure moves always animate the real window.
    var resizeAnimation: ResizeAnimation { didSet { save(resizeAnimation.rawValue, .resizeAnimation) } }
    var overlayStyle: OverlayStyle { didSet { save(overlayStyle.rawValue, .overlayStyle) } }
    /// When off, the app has no visible UI. Launching it again opens Preferences.
    var showMenuBarIcon: Bool { didSet { save(showMenuBarIcon, .showMenuBarIcon) } }

    /// Extra widths to cycle through besides 1/2, which is always on.
    var extraFractions: Set<WidthFraction> {
        didSet {
            for (fraction, key) in Self.fractionKeys {
                save(extraFractions.contains(fraction), key)
            }
        }
    }

    /// Modifiers for snap/maximize/restore/center. Arrows are fixed.
    var tilingModifiers: NSEvent.ModifierFlags { didSet { save(Self.carbon(tilingModifiers), .tilingModifiers) } }
    /// Modifiers for moving between monitors with the arrows.
    var monitorModifiers: NSEvent.ModifierFlags { didSet { save(Self.carbon(monitorModifiers), .monitorModifiers) } }
    /// Carbon key codes for the configurable keys.
    var maximizeKey: Int { didSet { save(maximizeKey, .maximizeKey) } }
    var restoreKey: Int { didSet { save(restoreKey, .restoreKey) } }
    var centerKey: Int { didSet { save(centerKey, .centerKey) } }

    private static let fractionKeys: [(WidthFraction, Key)] = [
        (.quarter, .fractionQuarter), (.third, .fractionThird),
        (.twoThirds, .fractionTwoThirds), (.threeQuarters, .fractionThreeQuarters),
    ]

    private init() {
        let d = UserDefaults.standard
        Self.migrateLegacyKeys(d)

        func bool(_ key: Key, _ fallback: Bool) -> Bool { d.object(forKey: key.rawValue) as? Bool ?? fallback }
        func int(_ key: Key, _ fallback: Int) -> Int { d.object(forKey: key.rawValue) as? Int ?? fallback }

        windowGap = CGFloat(d.double(forKey: Key.windowGap.rawValue))
        minimizeEnabled = bool(.minimizeEnabled, true)
        restoreSizeOnUntile = bool(.restoreSizeOnUntile, false)
        animationsEnabled = bool(.animationsEnabled, true)
        showMenuBarIcon = bool(.showMenuBarIcon, true)
        overlayStyle = d.string(forKey: Key.overlayStyle.rawValue).flatMap(OverlayStyle.init) ?? .liquidGlass
        resizeAnimation = d.string(forKey: Key.resizeAnimation.rawValue).flatMap(ResizeAnimation.init) ?? .glass
        extraFractions = Set(Self.fractionKeys.filter { bool($0.1, false) }.map(\.0))
        tilingModifiers = Self.modifiers(fromCarbon: int(.tilingModifiers, cmdKey | optionKey))
        monitorModifiers = Self.modifiers(fromCarbon: int(.monitorModifiers, controlKey | cmdKey | optionKey))
        maximizeKey = int(.maximizeKey, kVK_Return)
        restoreKey = int(.restoreKey, kVK_Delete)
        centerKey = int(.centerKey, kVK_ANSI_C)
    }

    /// Sorted widths for cycling, 1/2 always included.
    var enabledWidthFractions: [WidthFraction] {
        (extraFractions.union([.half])).sorted()
    }

    // MARK: - Launch at login

    /// Read from the system, not stored: the user can change it in
    /// System Settings > General > Login Items behind our back.
    var launchAtLogin: Bool {
        get {
            access(keyPath: \.launchAtLogin)
            return SMAppService.mainApp.status == .enabled
        }
        set {
            withMutation(keyPath: \.launchAtLogin) {
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    Log.error("Failed to update launch at login: \(error)")
                }
            }
        }
    }

    // MARK: - Persistence

    /// Some pre-release builds stored widths as "fraction_quarter" etc.
    /// Carry those over once so nobody loses their width cycle.
    private static func migrateLegacyKeys(_ d: UserDefaults) {
        for (fraction, key) in fractionKeys {
            let legacy = "fraction_\(fraction.rawValue)"
            guard let value = d.object(forKey: legacy) else { continue }
            if d.object(forKey: key.rawValue) == nil {
                d.set(value, forKey: key.rawValue)
            }
            d.removeObject(forKey: legacy)
        }
    }

    private func save(_ value: Any, _ key: Key) {
        defaults.set(value, forKey: key.rawValue)
    }

    // Modifiers are stored as Carbon flags (cmdKey, optionKey, ...) for a stable integer format.
    private static func carbon(_ flags: NSEvent.ModifierFlags) -> Int {
        var carbon = 0
        if flags.contains(.control) { carbon |= controlKey }
        if flags.contains(.option) { carbon |= optionKey }
        if flags.contains(.shift) { carbon |= shiftKey }
        if flags.contains(.command) { carbon |= cmdKey }
        return carbon
    }

    private static func modifiers(fromCarbon carbon: Int) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & controlKey != 0 { flags.insert(.control) }
        if carbon & optionKey != 0 { flags.insert(.option) }
        if carbon & shiftKey != 0 { flags.insert(.shift) }
        if carbon & cmdKey != 0 { flags.insert(.command) }
        return flags
    }
}

enum ResizeAnimation: String, CaseIterable {
    /// Smooth overlay animation, the real window resizes once. Works with any app.
    case glass
    /// Resize the real window every frame. Smooth only for light apps.
    case live

    var title: String {
        switch self {
        case .glass: return "Glass (smooth with any app)"
        case .live: return "Live (resizes the real window)"
        }
    }
}
