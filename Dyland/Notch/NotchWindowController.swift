import AppKit
import Combine
import SwiftUI

/// Owns the notch panel: creating it, placing it on the right screen, keeping
/// its hit region in sync with the state machine, and tearing it down.
///
/// This is the only type in the app that knows both AppKit windows and the
/// notch state machine; the SwiftUI layer below it is platform-agnostic.
@MainActor
final class NotchWindowController {

    let environment: AppEnvironment
    // Internal so the panel-construction extension in the neighbouring file
    // can assign them.
    var panel: NotchPanel?
    var hostView: NotchHostView?
    private var screenObserver: ScreenObserver?
    private var cancellables = Set<AnyCancellable>()

    /// Screen the panel is currently pinned to, remembered by display ID so a
    /// re-plugged monitor is recognised as the same one.
    private var currentDisplayID: CGDirectDisplayID?

    /// Set when the user hides the notch from the menu bar; survives screen
    /// changes so a reconfiguration does not resurrect a hidden panel.
    private(set) var isHiddenByUser = false

    /// Injected by `AppDelegate` once the shelf exists (Phase 2).
    var dropHandler: (([URL]) -> Bool)?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    // MARK: - Lifecycle

    func start() {
        rebuildForCurrentScreen()
        screenObserver = ScreenObserver { [weak self] in
            self?.rebuildForCurrentScreen()
        }

        // The hit region depends on state *and* on whether media is loaded,
        // because a collapsed notch widens into the peek presentation when
        // something is playing.
        environment.stateMachine.stateChanges
            .sink { [weak self] _ in self?.applyInteractiveRegion() }
            .store(in: &cancellables)

        environment.media.$snapshot
            .map { $0?.track != nil }
            .removeDuplicates()
            .sink { [weak self] _ in self?.applyInteractiveRegion() }
            .store(in: &cancellables)

        environment.settings.$showWaveform
            .sink { [weak self] _ in self?.applyInteractiveRegion() }
            .store(in: &cancellables)

        // Settings that change geometry or timing must reach the live panel.
        environment.settings.$sizing
            .dropFirst()
            .sink { [weak self] _ in self?.rebuildForCurrentScreen() }
            .store(in: &cancellables)

        Publishers.CombineLatest3(
            environment.settings.$hoverExpansionEnabled,
            environment.settings.$expansionDelay,
            environment.settings.$collapseDelay
        )
        .sink { [weak self] _, _, _ in
            guard let self else { return }
            self.environment.stateMachine.apply(
                config: self.environment.settings.notchConfig,
                availableSections: self.environment.settings.enabledSections
            )
        }
        .store(in: &cancellables)
    }

    func show() {
        isHiddenByUser = false
        if panel == nil { rebuildForCurrentScreen() }
        panel?.orderFrontRegardless()
    }

    func hide() {
        isHiddenByUser = true
        environment.stateMachine.reset()
        panel?.orderOut(nil)
    }

    func toggleVisibility() {
        isHiddenByUser ? show() : hide()
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func tearDown() {
        cancellables.removeAll()
        screenObserver = nil
        panel?.orderOut(nil)
        panel = nil
        hostView = nil
    }

    // MARK: - Screen placement

    /// Bridges `NSScreen.screens` into the pure selection policy.
    private func targetScreen() -> NSScreen? {
        let screens = NSScreen.screens
        guard let index = NotchScreenSelector.selectIndex(from: screens.map(\.notchDescriptor)) else {
            return NSScreen.main
        }
        return screens[index]
    }

    private func rebuildForCurrentScreen() {
        guard let screen = targetScreen() else {
            // No displays at all: clamshell with the lid closed and no external
            // monitor. Drop the panel; it is rebuilt when a screen returns.
            Log.notch.notice("No usable screen; tearing down the notch panel")
            panel?.orderOut(nil)
            panel = nil
            hostView = nil
            currentDisplayID = nil
            return
        }

        let geometry = NotchGeometryProvider.resolve(
            screen: screen.notchDescriptor,
            metrics: environment.settings.metrics
        )

        // Space switches and wake fire the same notification as a real display
        // change. Re-laying out an unchanged panel is wasted work and makes the
        // logs unreadable, so bail when nothing actually moved.
        if panel != nil,
           screen.displayID == currentDisplayID,
           geometry == environment.geometryStore.geometry {
            return
        }

        environment.geometryStore.update(geometry)

        if panel == nil {
            buildPanel(with: geometry)
        } else {
            panel?.setFrame(geometry.windowFrame, display: true)
        }

        currentDisplayID = screen.displayID
        hostView?.frame = CGRect(origin: .zero, size: geometry.windowSize)
        hostView?.dragCatchZone = geometry.dragCatchZone
        applyInteractiveRegion()

        if !isHiddenByUser {
            panel?.orderFrontRegardless()
        }

        Log.notch.info("""
            Notch placed on display \(String(describing: screen.displayID), privacy: .public) \
            notch=\(geometry.hasPhysicalNotch ? "physical" : "synthetic", privacy: .public) \
            size=\(Int(geometry.notchSize.width))x\(Int(geometry.notchSize.height))
            """)
    }

    // MARK: - Hit region

    private func applyInteractiveRegion() {
        guard let hostView else { return }
        let presentation = NotchPresentationResolver.resolve(
            state: environment.stateMachine.state,
            hasMedia: environment.media.track != nil,
            waveformEnabled: environment.settings.showWaveform
        )
        hostView.interactiveRect = environment.geometryStore.geometry.interactiveRect(for: presentation)
    }
}
