import SwiftUI
import KeyboardShortcuts

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 450, height: 300)
    }
}

struct GeneralSettingsView: View {
    @State private var launchAtLogin: Bool = Settings.shared.launchAtLogin
    @State private var windowGap: Double = Double(Settings.shared.windowGap)

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { newValue in
                    Settings.shared.launchAtLogin = newValue
                }

            HStack {
                Text("Window gap:")
                Slider(value: $windowGap, in: 0...20, step: 1)
                    .frame(width: 150)
                Text("\(Int(windowGap)) px")
                    .frame(width: 40)
            }
            .onChange(of: windowGap) { newValue in
                Settings.shared.windowGap = CGFloat(newValue)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct ShortcutsSettingsView: View {
    var body: some View {
        Form {
            shortcutRow("Snap Left", name: .snapLeft)
            shortcutRow("Snap Right", name: .snapRight)
            shortcutRow("Snap Up", name: .snapUp)
            shortcutRow("Snap Down", name: .snapDown)
            Divider()
            shortcutRow("Maximize", name: .maximize)
            shortcutRow("Restore", name: .restore)
            shortcutRow("Center", name: .center)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func shortcutRow(_ title: String, name: KeyboardShortcuts.Name) -> some View {
        HStack {
            Text(title)
                .frame(width: 100, alignment: .leading)
            KeyboardShortcuts.Recorder(for: name)
        }
    }
}

struct AboutView: View {
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.split.2x2")
                .font(.system(size: 64))
                .foregroundColor(.accentColor)

            Text("MacTiler")
                .font(.title)
                .fontWeight(.bold)

            Text("Version \(version)")
                .foregroundColor(.secondary)

            Text("Windows 11-style window tiling for macOS")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Link("GitHub", destination: URL(string: "https://github.com")!)
                .font(.subheadline)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
