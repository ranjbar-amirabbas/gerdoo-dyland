import Combine
import Foundation

/// Observable façade over `SettingsStore`.
///
/// Every property writes through on `didSet`, so there is no explicit "save"
/// step and no chance of the UI and the store disagreeing.
@MainActor
final class SettingsManager: ObservableObject {

    private let store: SettingsStore
    /// Suppresses write-back while the initial values are being loaded.
    private var isLoading = true

    // MARK: General

    @Published var launchAtLogin: Bool = false { didSet { persist(launchAtLogin, .launchAtLogin) } }
    @Published var hoverExpansionEnabled: Bool = true { didSet { persist(hoverExpansionEnabled, .hoverExpansionEnabled) } }
    @Published var expansionDelay: Double = 0.25 { didSet { persist(expansionDelay, .expansionDelay) } }
    @Published var collapseDelay: Double = 0.45 { didSet { persist(collapseDelay, .collapseDelay) } }

    // MARK: Modules

    @Published var nowPlayingEnabled: Bool = true { didSet { persist(nowPlayingEnabled, .nowPlayingEnabled) } }
    @Published var fileShelfEnabled: Bool = true { didSet { persist(fileShelfEnabled, .fileShelfEnabled) } }
    @Published var clipboardEnabled: Bool = true { didSet { persist(clipboardEnabled, .clipboardEnabled) } }
    @Published var quickActionsEnabled: Bool = true { didSet { persist(quickActionsEnabled, .quickActionsEnabled) } }

    // MARK: Appearance

    @Published var sizing: NotchSizing = .comfortable { didSet { persist(sizing.rawValue, .sizing) } }
    @Published var animationIntensity: AnimationIntensity = .full { didSet { persist(animationIntensity.rawValue, .animationIntensity) } }
    @Published var showWaveform: Bool = true { didSet { persist(showWaveform, .showWaveform) } }

    init(store: SettingsStore = SettingsStore()) {
        self.store = store
        load()
        isLoading = false
    }

    private func load() {
        launchAtLogin = store.bool(.launchAtLogin)
        hoverExpansionEnabled = store.bool(.hoverExpansionEnabled)
        expansionDelay = store.double(.expansionDelay)
        collapseDelay = store.double(.collapseDelay)

        nowPlayingEnabled = store.bool(.nowPlayingEnabled)
        fileShelfEnabled = store.bool(.fileShelfEnabled)
        clipboardEnabled = store.bool(.clipboardEnabled)
        quickActionsEnabled = store.bool(.quickActionsEnabled)

        sizing = store.string(.sizing).flatMap(NotchSizing.init(rawValue:)) ?? .comfortable
        animationIntensity = store.string(.animationIntensity).flatMap(AnimationIntensity.init(rawValue:)) ?? .full
        showWaveform = store.bool(.showWaveform)
    }

    private func persist(_ value: Bool, _ key: SettingsKey) {
        guard !isLoading else { return }
        store.set(value, for: key)
    }

    private func persist(_ value: Double, _ key: SettingsKey) {
        guard !isLoading else { return }
        store.set(value, for: key)
    }

    private func persist(_ value: String, _ key: SettingsKey) {
        guard !isLoading else { return }
        store.set(value, for: key)
    }

    // MARK: Derived

    /// Sections the user has actually enabled, in display order.
    var enabledSections: [NotchSection] {
        var sections: [NotchSection] = []
        if nowPlayingEnabled { sections.append(.nowPlaying) }
        if fileShelfEnabled { sections.append(.fileShelf) }
        if clipboardEnabled { sections.append(.clipboard) }
        if quickActionsEnabled { sections.append(.quickActions) }
        return sections
    }

    /// Config snapshot for the state machine. `defaultSection` degrades to the
    /// first enabled module so disabling Now Playing cannot open an empty panel.
    var notchConfig: NotchStateConfig {
        NotchStateConfig(
            hoverExpansionEnabled: hoverExpansionEnabled,
            expansionDelay: expansionDelay,
            collapseDelay: collapseDelay,
            defaultSection: enabledSections.first ?? .quickActions
        )
    }

    var metrics: NotchMetrics {
        NotchMetrics(sizing: sizing)
    }
}
