import SwiftUI

struct GeneralSettingsPane: View {

    @EnvironmentObject private var settings: SettingsManager
    @State private var loginItemWarning: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch Dyland at login", isOn: Binding(
                    get: { settings.launchAtLogin },
                    set: { applyLaunchAtLogin($0) }
                ))
                if let loginItemWarning {
                    Text(loginItemWarning)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Interaction") {
                Toggle("Expand when the pointer is over the notch", isOn: $settings.hoverExpansionEnabled)

                LabeledContent("Expansion delay") {
                    delaySlider(value: $settings.expansionDelay, range: 0...1.0)
                }
                .disabled(!settings.hoverExpansionEnabled)

                LabeledContent("Collapse delay") {
                    delaySlider(value: $settings.collapseDelay, range: 0.1...2.0)
                }
            }
        }
        .formStyle(.grouped)
        .frame(height: 260)
        .onAppear { loginItemWarning = LaunchAtLogin.statusDescription }
    }

    private func delaySlider(value: Binding<Double>, range: ClosedRange<Double>) -> some View {
        HStack {
            Slider(value: value, in: range)
            Text(String(format: "%.2fs", value.wrappedValue))
                .font(.caption.monospacedDigit())
                .frame(width: 46, alignment: .trailing)
        }
    }

    /// The toggle reflects the *actual* login-item state: if registration is
    /// refused (app not in /Applications, approval pending) it snaps back and
    /// explains why rather than silently claiming success.
    private func applyLaunchAtLogin(_ enabled: Bool) {
        settings.launchAtLogin = enabled
        guard let resulting = LaunchAtLogin.apply(enabled) else {
            settings.launchAtLogin = LaunchAtLogin.isEnabled
            loginItemWarning = "Could not change the login item. Check System Settings ▸ General ▸ Login Items."
            return
        }
        settings.launchAtLogin = resulting
        loginItemWarning = LaunchAtLogin.statusDescription
    }
}
