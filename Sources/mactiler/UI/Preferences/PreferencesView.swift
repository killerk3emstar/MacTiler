import SwiftUI
import KeyboardShortcuts
import Carbon.HIToolbox

struct PreferencesView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                Text("General").tag(0)
                Text("Shortcuts").tag(1)
                Text("About").tag(2)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 60)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider()

            Group {
                switch selectedTab {
                case 0: GeneralSettingsView()
                case 1: ShortcutsSettingsView()
                case 2: AboutView()
                default: EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 460, minHeight: 380)
    }
}

struct GeneralSettingsView: View {
    @State private var launchAtLogin = Settings.shared.launchAtLogin
    @AppStorage("minimizeEnabled") private var minimizeEnabled: Bool = true
    @AppStorage("restoreSizeOnUntile") private var restoreSizeOnUntile: Bool = false
    @AppStorage("animationsEnabled") private var animationsEnabled: Bool = true
    @AppStorage("windowGap") private var windowGap: Double = 0

    @AppStorage("fractionQuarter") private var quarterEnabled = false
    @AppStorage("fractionThird") private var thirdEnabled = false
    @AppStorage("fractionTwoThirds") private var twoThirdsEnabled = false
    @AppStorage("fractionThreeQuarters") private var threeQuartersEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        Settings.shared.launchAtLogin = newValue
                    }
            }

            Section("Behavior") {
                Toggle("Enable minimize/unminimize", isOn: $minimizeEnabled)

                Toggle("Restore original size when untiled", isOn: $restoreSizeOnUntile)

                Toggle("Animate window transitions", isOn: $animationsEnabled)
            }

            Section("Tiling Sizes") {
                Text("Sizes to cycle through when pressing the same direction repeatedly")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                Toggle("1/4", isOn: $quarterEnabled)
                Toggle("1/3", isOn: $thirdEnabled)
                Toggle("1/2 (always enabled)", isOn: .constant(true)).disabled(true)
                Toggle("2/3", isOn: $twoThirdsEnabled)
                Toggle("3/4", isOn: $threeQuartersEnabled)
            }

            Section("Window Gap") {
                HStack {
                    Slider(value: $windowGap, in: 0...20, step: 1)
                    Text("\(Int(windowGap)) px")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Configurable key options for Maximize/Restore/Center

struct ConfigurableKey: Identifiable, Hashable {
    let name: String
    let rawValue: Int

    var id: Int { rawValue }
}

private let configurableKeys: [ConfigurableKey] = [
    ConfigurableKey(name: "Return", rawValue: kVK_Return),
    ConfigurableKey(name: "Delete", rawValue: kVK_Delete),
    ConfigurableKey(name: "Space", rawValue: kVK_Space),
    ConfigurableKey(name: "Tab", rawValue: kVK_Tab),
    ConfigurableKey(name: "Escape", rawValue: kVK_Escape),
    ConfigurableKey(name: "A", rawValue: kVK_ANSI_A),
    ConfigurableKey(name: "B", rawValue: kVK_ANSI_B),
    ConfigurableKey(name: "C", rawValue: kVK_ANSI_C),
    ConfigurableKey(name: "D", rawValue: kVK_ANSI_D),
    ConfigurableKey(name: "E", rawValue: kVK_ANSI_E),
    ConfigurableKey(name: "F", rawValue: kVK_ANSI_F),
    ConfigurableKey(name: "G", rawValue: kVK_ANSI_G),
    ConfigurableKey(name: "H", rawValue: kVK_ANSI_H),
    ConfigurableKey(name: "I", rawValue: kVK_ANSI_I),
    ConfigurableKey(name: "J", rawValue: kVK_ANSI_J),
    ConfigurableKey(name: "K", rawValue: kVK_ANSI_K),
    ConfigurableKey(name: "L", rawValue: kVK_ANSI_L),
    ConfigurableKey(name: "M", rawValue: kVK_ANSI_M),
    ConfigurableKey(name: "N", rawValue: kVK_ANSI_N),
    ConfigurableKey(name: "O", rawValue: kVK_ANSI_O),
    ConfigurableKey(name: "P", rawValue: kVK_ANSI_P),
    ConfigurableKey(name: "Q", rawValue: kVK_ANSI_Q),
    ConfigurableKey(name: "R", rawValue: kVK_ANSI_R),
    ConfigurableKey(name: "S", rawValue: kVK_ANSI_S),
    ConfigurableKey(name: "T", rawValue: kVK_ANSI_T),
    ConfigurableKey(name: "U", rawValue: kVK_ANSI_U),
    ConfigurableKey(name: "V", rawValue: kVK_ANSI_V),
    ConfigurableKey(name: "W", rawValue: kVK_ANSI_W),
    ConfigurableKey(name: "X", rawValue: kVK_ANSI_X),
    ConfigurableKey(name: "Y", rawValue: kVK_ANSI_Y),
    ConfigurableKey(name: "Z", rawValue: kVK_ANSI_Z),
    ConfigurableKey(name: "0", rawValue: kVK_ANSI_0),
    ConfigurableKey(name: "1", rawValue: kVK_ANSI_1),
    ConfigurableKey(name: "2", rawValue: kVK_ANSI_2),
    ConfigurableKey(name: "3", rawValue: kVK_ANSI_3),
    ConfigurableKey(name: "4", rawValue: kVK_ANSI_4),
    ConfigurableKey(name: "5", rawValue: kVK_ANSI_5),
    ConfigurableKey(name: "6", rawValue: kVK_ANSI_6),
    ConfigurableKey(name: "7", rawValue: kVK_ANSI_7),
    ConfigurableKey(name: "8", rawValue: kVK_ANSI_8),
    ConfigurableKey(name: "9", rawValue: kVK_ANSI_9),
    ConfigurableKey(name: "F1", rawValue: kVK_F1),
    ConfigurableKey(name: "F2", rawValue: kVK_F2),
    ConfigurableKey(name: "F3", rawValue: kVK_F3),
    ConfigurableKey(name: "F4", rawValue: kVK_F4),
    ConfigurableKey(name: "F5", rawValue: kVK_F5),
    ConfigurableKey(name: "F6", rawValue: kVK_F6),
    ConfigurableKey(name: "F7", rawValue: kVK_F7),
    ConfigurableKey(name: "F8", rawValue: kVK_F8),
    ConfigurableKey(name: "F9", rawValue: kVK_F9),
    ConfigurableKey(name: "F10", rawValue: kVK_F10),
    ConfigurableKey(name: "F11", rawValue: kVK_F11),
    ConfigurableKey(name: "F12", rawValue: kVK_F12),
]

// MARK: - Modifier toggle button

struct ModifierToggle: View {
    let symbol: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Text(symbol)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 28, height: 22)
        }
        .buttonStyle(.bordered)
        .tint(isOn ? .accentColor : nil)
        .opacity(isOn ? 1.0 : 0.5)
    }
}

// MARK: - Shortcuts Settings View

struct ShortcutsSettingsView: View {
    @State private var tilingCommand: Bool
    @State private var tilingOption: Bool
    @State private var tilingControl: Bool
    @State private var tilingShift: Bool

    @State private var monitorCommand: Bool
    @State private var monitorOption: Bool
    @State private var monitorControl: Bool
    @State private var monitorShift: Bool

    @State private var maximizeKey: Int
    @State private var restoreKey: Int
    @State private var centerKey: Int

    @State private var validationError: String?

    init() {
        let tiling: NSEvent.ModifierFlags = Settings.shared.tilingModifiers
        _tilingCommand = State(initialValue: tiling.contains(.command))
        _tilingOption = State(initialValue: tiling.contains(.option))
        _tilingControl = State(initialValue: tiling.contains(.control))
        _tilingShift = State(initialValue: tiling.contains(.shift))

        let monitor: NSEvent.ModifierFlags = Settings.shared.monitorModifiers
        _monitorCommand = State(initialValue: monitor.contains(.command))
        _monitorOption = State(initialValue: monitor.contains(.option))
        _monitorControl = State(initialValue: monitor.contains(.control))
        _monitorShift = State(initialValue: monitor.contains(.shift))

        _maximizeKey = State(initialValue: Settings.shared.maximizeKey)
        _restoreKey = State(initialValue: Settings.shared.restoreKey)
        _centerKey = State(initialValue: Settings.shared.centerKey)
    }

    private var tilingModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if tilingCommand { flags.insert(.command) }
        if tilingOption { flags.insert(.option) }
        if tilingControl { flags.insert(.control) }
        if tilingShift { flags.insert(.shift) }
        return flags
    }

    private var monitorModifiers: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if monitorCommand { flags.insert(.command) }
        if monitorOption { flags.insert(.option) }
        if monitorControl { flags.insert(.control) }
        if monitorShift { flags.insert(.shift) }
        return flags
    }

    private var tilingModifierString: String {
        modifierString(tilingModifiers)
    }

    private var monitorModifierString: String {
        modifierString(monitorModifiers)
    }

    private func modifierString(_ flags: NSEvent.ModifierFlags) -> String {
        var parts: [String] = []
        if flags.contains(.control) { parts.append("\u{2303}") }
        if flags.contains(.option) { parts.append("\u{2325}") }
        if flags.contains(.shift) { parts.append("\u{21E7}") }
        if flags.contains(.command) { parts.append("\u{2318}") }
        return parts.joined()
    }

    private func validate() -> String? {
        if tilingModifiers.isEmpty {
            return "Tiling shortcuts need at least one modifier."
        }
        if monitorModifiers.isEmpty {
            return "Monitor shortcuts need at least one modifier."
        }
        if tilingModifiers == monitorModifiers {
            return "Tiling and monitor modifiers must be different (arrow keys would conflict)."
        }
        if Set([maximizeKey, restoreKey, centerKey]).count < 3 {
            return "Maximize, Restore and Center must use different keys."
        }
        return nil
    }

    private func applyChanges() {
        if let error = validate() {
            validationError = error
            return
        }
        validationError = nil
        Settings.shared.tilingModifiers = tilingModifiers
        Settings.shared.monitorModifiers = monitorModifiers
        Settings.shared.maximizeKey = maximizeKey
        Settings.shared.restoreKey = restoreKey
        Settings.shared.centerKey = centerKey
        ShortcutManager.shared.rebuildAllShortcuts()
    }

    var body: some View {
        Form {
            Section("Tiling Shortcuts") {
                LabeledContent("Modifiers") {
                    HStack(spacing: 4) {
                        ModifierToggle(symbol: "\u{2303}", isOn: $tilingControl)
                        ModifierToggle(symbol: "\u{2325}", isOn: $tilingOption)
                        ModifierToggle(symbol: "\u{21E7}", isOn: $tilingShift)
                        ModifierToggle(symbol: "\u{2318}", isOn: $tilingCommand)
                    }
                    .onChange(of: tilingControl) { applyChanges() }
                    .onChange(of: tilingOption) { applyChanges() }
                    .onChange(of: tilingShift) { applyChanges() }
                    .onChange(of: tilingCommand) { applyChanges() }
                }

                LabeledContent("Snap Left / Right / Up / Down") {
                    Text("\(tilingModifierString) + \u{2190}\u{2192}\u{2191}\u{2193}")
                        .foregroundStyle(.secondary)
                }

                LabeledContent("Maximize") {
                    HStack {
                        Text(tilingModifierString)
                            .foregroundStyle(.secondary)
                        Text("+")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $maximizeKey) {
                            ForEach(configurableKeys) { key in
                                Text(key.name).tag(key.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        .onChange(of: maximizeKey) { applyChanges() }
                    }
                }

                LabeledContent("Restore") {
                    HStack {
                        Text(tilingModifierString)
                            .foregroundStyle(.secondary)
                        Text("+")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $restoreKey) {
                            ForEach(configurableKeys) { key in
                                Text(key.name).tag(key.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        .onChange(of: restoreKey) { applyChanges() }
                    }
                }

                LabeledContent("Center") {
                    HStack {
                        Text(tilingModifierString)
                            .foregroundStyle(.secondary)
                        Text("+")
                            .foregroundStyle(.secondary)
                        Picker("", selection: $centerKey) {
                            ForEach(configurableKeys) { key in
                                Text(key.name).tag(key.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 90)
                        .onChange(of: centerKey) { applyChanges() }
                    }
                }
            }

            Section("Monitor Shortcuts") {
                LabeledContent("Modifiers") {
                    HStack(spacing: 4) {
                        ModifierToggle(symbol: "\u{2303}", isOn: $monitorControl)
                        ModifierToggle(symbol: "\u{2325}", isOn: $monitorOption)
                        ModifierToggle(symbol: "\u{21E7}", isOn: $monitorShift)
                        ModifierToggle(symbol: "\u{2318}", isOn: $monitorCommand)
                    }
                    .onChange(of: monitorControl) { applyChanges() }
                    .onChange(of: monitorOption) { applyChanges() }
                    .onChange(of: monitorShift) { applyChanges() }
                    .onChange(of: monitorCommand) { applyChanges() }
                }

                LabeledContent("Move Left / Right / Up / Down") {
                    Text("\(monitorModifierString) + \u{2190}\u{2192}\u{2191}\u{2193}")
                        .foregroundStyle(.secondary)
                }
            }

            if let error = validationError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.primary)

            Text("MacTiler")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Version \(version) (\(build))")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Window tiling for macOS,\ninspired by Windows 11 Snap Assist")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(2)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
