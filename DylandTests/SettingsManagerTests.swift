import XCTest
@testable import Dyland

@MainActor
final class SettingsManagerTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        try super.setUpWithError()
        suiteName = "DylandSettingsTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        try super.tearDownWithError()
    }

    private func makeManager() -> SettingsManager {
        SettingsManager(store: SettingsStore(defaults: defaults))
    }

    func testDefaultsAreSensible() {
        let settings = makeManager()

        XCTAssertFalse(settings.launchAtLogin)
        XCTAssertTrue(settings.hoverExpansionEnabled)
        XCTAssertEqual(settings.expansionDelay, 0.25, accuracy: 0.0001)
        XCTAssertEqual(settings.collapseDelay, 0.45, accuracy: 0.0001)
        XCTAssertTrue(settings.nowPlayingEnabled)
        XCTAssertTrue(settings.fileShelfEnabled)
        XCTAssertTrue(settings.clipboardEnabled)
        XCTAssertTrue(settings.quickActionsEnabled)
        XCTAssertEqual(settings.sizing, .comfortable)
        XCTAssertEqual(settings.animationIntensity, .full)
        XCTAssertTrue(settings.showWaveform)
    }

    func testChangesSurviveANewManager() {
        let first = makeManager()
        first.hoverExpansionEnabled = false
        first.collapseDelay = 1.25
        first.sizing = .compact
        first.animationIntensity = .none

        let second = makeManager()

        XCTAssertFalse(second.hoverExpansionEnabled)
        XCTAssertEqual(second.collapseDelay, 1.25, accuracy: 0.0001)
        XCTAssertEqual(second.sizing, .compact)
        XCTAssertEqual(second.animationIntensity, .none)
    }

    func testLoadingDoesNotWriteBackDefaults() {
        _ = makeManager()
        // `register(defaults:)` values must not be promoted into the persistent
        // domain, or a future change of default would never reach the user.
        // (`object(forKey:)` would find the registration domain, so check the
        // persistent domain directly.)
        let persisted = defaults.persistentDomain(forName: suiteName) ?? [:]
        XCTAssertNil(persisted[SettingsKey.collapseDelay.rawValue])
        XCTAssertNil(persisted[SettingsKey.sizing.rawValue])
    }

    func testUnknownStoredEnumFallsBackToTheDefault() {
        defaults.set("nonsense", forKey: SettingsKey.sizing.rawValue)
        defaults.set("nonsense", forKey: SettingsKey.animationIntensity.rawValue)

        let settings = makeManager()

        XCTAssertEqual(settings.sizing, .comfortable)
        XCTAssertEqual(settings.animationIntensity, .full)
    }

    // MARK: Derived values

    func testEnabledSectionsFollowTheModuleToggles() {
        let settings = makeManager()
        XCTAssertEqual(settings.enabledSections, [.nowPlaying, .fileShelf, .clipboard, .quickActions])

        settings.nowPlayingEnabled = false
        settings.clipboardEnabled = false

        XCTAssertEqual(settings.enabledSections, [.fileShelf, .quickActions])
    }

    func testDefaultSectionDegradesToTheFirstEnabledModule() {
        let settings = makeManager()
        settings.nowPlayingEnabled = false

        XCTAssertEqual(settings.notchConfig.defaultSection, .fileShelf)
    }

    func testDefaultSectionSurvivesEveryModuleBeingOff() {
        let settings = makeManager()
        settings.nowPlayingEnabled = false
        settings.fileShelfEnabled = false
        settings.clipboardEnabled = false
        settings.quickActionsEnabled = false

        XCTAssertTrue(settings.enabledSections.isEmpty)
        XCTAssertEqual(settings.notchConfig.defaultSection, .quickActions,
                       "The config must never produce an invalid section")
    }

    func testNotchConfigMirrorsTheTimingSettings() {
        let settings = makeManager()
        settings.hoverExpansionEnabled = false
        settings.expansionDelay = 0.5
        settings.collapseDelay = 0.9

        let config = settings.notchConfig

        XCTAssertFalse(config.hoverExpansionEnabled)
        XCTAssertEqual(config.expansionDelay, 0.5, accuracy: 0.0001)
        XCTAssertEqual(config.collapseDelay, 0.9, accuracy: 0.0001)
    }

    func testMetricsFollowTheSizingSetting() {
        let settings = makeManager()
        let comfortable = settings.metrics.expandedWidth
        settings.sizing = .compact

        XCTAssertLessThan(settings.metrics.expandedWidth, comfortable)
    }
}
