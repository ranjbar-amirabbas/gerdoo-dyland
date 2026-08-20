import SwiftUI

struct ModulesSettingsPane: View {

    @EnvironmentObject private var settings: SettingsManager

    var body: some View {
        Form {
            Section {
                Toggle("Now Playing", isOn: $settings.nowPlayingEnabled)
                Toggle("File Shelf", isOn: $settings.fileShelfEnabled)
                Toggle("Clipboard", isOn: $settings.clipboardEnabled)
                Toggle("Quick Actions", isOn: $settings.quickActionsEnabled)
            } footer: {
                Text("Disabling a module stops its observers entirely — it is not just hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("Now Playing reads Music and Spotify over Apple events. macOS will ask for Automation permission the first time \(AppInfo.displayName) sends a playback command.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Clipboard history is kept in memory only, up to 10 entries, and is never written to disk.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 300)
    }
}
