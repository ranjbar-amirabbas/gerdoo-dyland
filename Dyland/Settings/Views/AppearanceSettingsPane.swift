import SwiftUI

struct AppearanceSettingsPane: View {

    @EnvironmentObject private var settings: SettingsManager

    var body: some View {
        Form {
            Section {
                Picker("Panel size", selection: $settings.sizing) {
                    ForEach(NotchSizing.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                Picker("Animation", selection: $settings.animationIntensity) {
                    ForEach(AnimationIntensity.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } footer: {
                Text("Animations are disabled automatically when Reduce Motion is on, whatever this is set to.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Show waveform while media plays", isOn: $settings.showWaveform)
            } footer: {
                Text("The waveform is a procedural animation. macOS has no public API for reading another app's audio levels without a screen-recording style permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(height: 280)
    }
}
