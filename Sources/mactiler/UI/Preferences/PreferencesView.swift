import SwiftUI
import Carbon.HIToolbox
import MacTilerCore

struct GeneralSettingsView: View {
    @Bindable private var settings = Settings.shared

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
            } footer: {
                if !settings.showMenuBarIcon {
                    Text("To get back here, open MacTiler again from Spotlight or Finder.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Behavior") {
                Toggle("Enable minimize/unminimize", isOn: $settings.minimizeEnabled)
                Toggle("Restore original size when dragged out of a tile", isOn: $settings.restoreSizeOnUntile)
                Toggle("Animate window transitions", isOn: $settings.animationsEnabled)
                Picker("Resize animation", selection: $settings.resizeAnimation) {
                    ForEach(ResizeAnimation.allCases, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }
                .disabled(!settings.animationsEnabled)
                Picker("Overlay style", selection: $settings.overlayStyle) {
                    ForEach(OverlayStyle.allCases, id: \.self) { style in
                        Text(style.title).tag(style)
                    }
                }
                .disabled(!overlayEnabled)
                PercentSlider(title: "Overlay opacity", value: $settings.overlayOpacity, range: 0.2...1)
                    .disabled(!overlayEnabled)
                HStack {
                    Spacer()
                    Button("Preview") { previewOverlay() }
                        .disabled(!overlayEnabled)
                }
            }

            Section("Tiling Sizes") {
                Text("Sizes to cycle through when pressing the same direction repeatedly")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                ForEach(WidthFraction.allCases, id: \.self) { fraction in
                    if fraction == .half {
                        Toggle("1/2 (always enabled)", isOn: .constant(true)).disabled(true)
                    } else {
                        Toggle(fraction.displayName, isOn: fractionBinding(fraction))
                    }
                }
            }

            Section("Window Gap") {
                HStack {
                    Slider(value: $settings.windowGap, in: 0...20, step: 1)
                    Text("\(Int(settings.windowGap)) px")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private var overlayEnabled: Bool {
        settings.animationsEnabled && settings.resizeAnimation == .glass
    }

    /// Plays the overlay over the Preferences window itself.
    private func previewOverlay() {
        guard let window = NSApp.keyWindow, let primary = NSScreen.screens.first else { return }
        WindowMover.shared.previewOverlay(around: Geometry.toAX(window.frame, primaryHeight: primary.frame.height))
    }

    private func fractionBinding(_ fraction: WidthFraction) -> Binding<Bool> {
        Binding(
            get: { settings.extraFractions.contains(fraction) },
            set: { isOn in
                if isOn {
                    settings.extraFractions.insert(fraction)
                } else {
                    settings.extraFractions.remove(fraction)
                }
            }
        )
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

// MARK: - Shortcuts

/// Edits a draft and only writes it to Settings when it is valid, so an
/// in-between state (e.g. no modifiers while toggling) never registers.
struct ShortcutsSettingsView: View {
    @State private var tiling = Settings.shared.tilingModifiers
    @State private var monitor = Settings.shared.monitorModifiers
    @State private var maximizeKey = Settings.shared.maximizeKey
    @State private var restoreKey = Settings.shared.restoreKey
    @State private var centerKey = Settings.shared.centerKey
    @State private var validationError: String?

    var body: some View {
        Form {
            Section("Tiling Shortcuts") {
                LabeledContent("Modifiers") { ModifierPicker(flags: $tiling) }

                LabeledContent("Snap Left / Right / Up / Down") {
                    Text("\(symbols(tiling)) + \u{2190}\u{2192}\u{2191}\u{2193}")
                        .foregroundStyle(.secondary)
                }

                KeyPickerRow(title: "Maximize", modifiers: tiling, key: $maximizeKey)
                KeyPickerRow(title: "Restore", modifiers: tiling, key: $restoreKey)
                KeyPickerRow(title: "Center", modifiers: tiling, key: $centerKey)
            }

            Section("Monitor Shortcuts") {
                LabeledContent("Modifiers") { ModifierPicker(flags: $monitor) }

                LabeledContent("Move Left / Right / Up / Down") {
                    Text("\(symbols(monitor)) + \u{2190}\u{2192}\u{2191}\u{2193}")
                        .foregroundStyle(.secondary)
                }
            }

            if let validationError {
                Section {
                    Label(validationError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.callout)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .onChange(of: tiling.rawValue) { apply() }
        .onChange(of: monitor.rawValue) { apply() }
        .onChange(of: maximizeKey) { apply() }
        .onChange(of: restoreKey) { apply() }
        .onChange(of: centerKey) { apply() }
    }

    private func validate() -> String? {
        if tiling.isEmpty { return "Tiling shortcuts need at least one modifier." }
        if monitor.isEmpty { return "Monitor shortcuts need at least one modifier." }
        if tiling == monitor { return "Tiling and monitor modifiers must be different (arrow keys would conflict)." }
        if Set([maximizeKey, restoreKey, centerKey]).count < 3 {
            return "Maximize, Restore and Center must use different keys."
        }
        return nil
    }

    private func apply() {
        validationError = validate()
        guard validationError == nil else { return }

        let settings = Settings.shared
        settings.tilingModifiers = tiling
        settings.monitorModifiers = monitor
        settings.maximizeKey = maximizeKey
        settings.restoreKey = restoreKey
        settings.centerKey = centerKey
        ShortcutAction.syncWithSettings()
    }
}

private func symbols(_ flags: NSEvent.ModifierFlags) -> String {
    var result = ""
    if flags.contains(.control) { result += "\u{2303}" }
    if flags.contains(.option) { result += "\u{2325}" }
    if flags.contains(.shift) { result += "\u{21E7}" }
    if flags.contains(.command) { result += "\u{2318}" }
    return result
}

/// Slider with a percentage readout.
struct PercentSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        LabeledContent(title) {
            HStack {
                Slider(value: $value, in: range)
                Text("\(Int((value * 100).rounded()))%")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 40, alignment: .trailing)
            }
        }
    }
}

/// Four toggle buttons (control, option, shift, command) bound to one flag set.
struct ModifierPicker: View {
    @Binding var flags: NSEvent.ModifierFlags

    private static let options: [(String, NSEvent.ModifierFlags)] = [
        ("\u{2303}", .control), ("\u{2325}", .option), ("\u{21E7}", .shift), ("\u{2318}", .command),
    ]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Self.options, id: \.0) { symbol, flag in
                let isOn = flags.contains(flag)
                Button {
                    if isOn { flags.remove(flag) } else { flags.insert(flag) }
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
    }
}

/// "Maximize   ⌥⌘ + [Return v]"
struct KeyPickerRow: View {
    let title: String
    let modifiers: NSEvent.ModifierFlags
    @Binding var key: Int

    var body: some View {
        LabeledContent(title) {
            HStack {
                Text("\(symbols(modifiers)) +")
                    .foregroundStyle(.secondary)
                Picker("", selection: $key) {
                    ForEach(configurableKeys) { option in
                        Text(option.name).tag(option.rawValue)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
            }
        }
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
