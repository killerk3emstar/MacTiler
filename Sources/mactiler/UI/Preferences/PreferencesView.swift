import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    @State private var selectedTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker in the style of native macOS preferences
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

            // Tab content
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
    @State private var windowGap = Double(Settings.shared.windowGap)
    @State private var minimizeEnabled = Settings.shared.minimizeEnabled
    @State private var restoreSizeOnUntile = Settings.shared.restoreSizeOnUntile
    @State private var animationsEnabled = Settings.shared.animationsEnabled

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { Settings.shared.launchAtLogin = $0 }
            }

            Section("Behavior") {
                Toggle("Enable minimize/unminimize", isOn: $minimizeEnabled)
                    .onChange(of: minimizeEnabled) { Settings.shared.minimizeEnabled = $0 }

                Toggle("Restore original size when untiled", isOn: $restoreSizeOnUntile)
                    .onChange(of: restoreSizeOnUntile) { Settings.shared.restoreSizeOnUntile = $0 }

                Toggle("Animate window transitions", isOn: $animationsEnabled)
                    .onChange(of: animationsEnabled) { Settings.shared.animationsEnabled = $0 }
            }

            Section("Window Gap") {
                HStack {
                    Slider(value: $windowGap, in: 0...20, step: 1)
                        .onChange(of: windowGap) { Settings.shared.windowGap = CGFloat($0) }
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

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            Section("Tiling") {
                shortcutRow("Snap Left", name: .snapLeft)
                shortcutRow("Snap Right", name: .snapRight)
                shortcutRow("Snap Up", name: .snapUp)
                shortcutRow("Snap Down", name: .snapDown)
            }

            Section("Window") {
                shortcutRow("Maximize", name: .maximize)
                shortcutRow("Restore", name: .restore)
                shortcutRow("Center", name: .center)
            }

            Section("Monitor") {
                shortcutRow("Move Left", name: .moveMonitorLeft)
                shortcutRow("Move Right", name: .moveMonitorRight)
                shortcutRow("Move Up", name: .moveMonitorUp)
                shortcutRow("Move Down", name: .moveMonitorDown)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }

    private func shortcutRow(_ title: String, name: KeyboardShortcuts.Name) -> some View {
        LabeledContent(title) {
            KeyboardShortcuts.Recorder(for: name)
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
