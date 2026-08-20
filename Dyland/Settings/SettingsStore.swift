import Foundation

/// Typed keys for everything Dyland persists.
///
/// Values live in `UserDefaults`; a settings bundle would be overkill for a
/// dozen scalars. The suite is injectable so tests never touch the real domain.
enum SettingsKey: String, CaseIterable {
    case launchAtLogin
    case hoverExpansionEnabled
    case expansionDelay
    case collapseDelay

    case nowPlayingEnabled
    case fileShelfEnabled
    case clipboardEnabled
    case quickActionsEnabled

    case sizing
    case animationIntensity
    case showWaveform
}

/// Thin, testable wrapper over `UserDefaults` with a single source of defaults.
final class SettingsStore {

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.defaults.register(defaults: Self.registrationDefaults)
    }

    private static var registrationDefaults: [String: Any] {
        [
            SettingsKey.launchAtLogin.rawValue: false,
            SettingsKey.hoverExpansionEnabled.rawValue: true,
            SettingsKey.expansionDelay.rawValue: 0.25,
            SettingsKey.collapseDelay.rawValue: 0.45,
            SettingsKey.nowPlayingEnabled.rawValue: true,
            SettingsKey.fileShelfEnabled.rawValue: true,
            SettingsKey.clipboardEnabled.rawValue: true,
            SettingsKey.quickActionsEnabled.rawValue: true,
            SettingsKey.sizing.rawValue: NotchSizing.comfortable.rawValue,
            SettingsKey.animationIntensity.rawValue: AnimationIntensity.full.rawValue,
            SettingsKey.showWaveform.rawValue: true
        ]
    }

    func bool(_ key: SettingsKey) -> Bool { defaults.bool(forKey: key.rawValue) }
    func double(_ key: SettingsKey) -> Double { defaults.double(forKey: key.rawValue) }
    func string(_ key: SettingsKey) -> String? { defaults.string(forKey: key.rawValue) }

    func set(_ value: Bool, for key: SettingsKey) { defaults.set(value, forKey: key.rawValue) }
    func set(_ value: Double, for key: SettingsKey) { defaults.set(value, forKey: key.rawValue) }
    func set(_ value: String, for key: SettingsKey) { defaults.set(value, forKey: key.rawValue) }

    /// Test helper: wipe every key this app owns from the backing suite.
    func removeAll() {
        for key in SettingsKey.allCases {
            defaults.removeObject(forKey: key.rawValue)
        }
    }
}
