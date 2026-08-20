import Combine
import Foundation

/// Owns the current `NotchState` and the single pending timer.
///
/// All decisions live in `NotchStateReducer`; this type only applies them and
/// manages the one outstanding `Task`. There is intentionally never more than
/// one timer in flight, which is why a stale fire cannot race a fresh state.
@MainActor
final class NotchStateMachine: ObservableObject {

    @Published private(set) var state: NotchState = .collapsed

    /// Fires on every accepted state change. Used by the window controller to
    /// resize the interactive hit region without observing SwiftUI.
    let stateChanges = PassthroughSubject<NotchState, Never>()

    var config: NotchStateConfig

    private var pendingTimer: Task<Void, Never>?

    init(config: NotchStateConfig = NotchStateConfig()) {
        self.config = config
    }

    deinit {
        pendingTimer?.cancel()
    }

    func send(_ event: NotchEvent) {
        rememberSection(from: event)
        let transition = NotchStateReducer.reduce(state: state, event: event, config: config)

        // Any transition supersedes the outstanding timer, including one that
        // schedules nothing — otherwise a collapse queued before the user came
        // back would still fire.
        pendingTimer?.cancel()
        pendingTimer = nil

        if transition.state != state {
            Log.notch.info("""
                \(String(describing: self.state), privacy: .public) \
                --\(String(describing: event), privacy: .public)--> \
                \(String(describing: transition.state), privacy: .public)
                """)
            state = transition.state
            stateChanges.send(transition.state)
        }

        if let scheduled = transition.scheduled {
            pendingTimer = Task { [weak self] in
                let nanoseconds = UInt64(max(0, scheduled.delay) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: nanoseconds)
                guard !Task.isCancelled else { return }
                self?.send(scheduled.event)
            }
        }
    }

    /// The notch reopens on whatever the user last looked at. Without this,
    /// hovering after choosing the File Shelf would silently snap back to Now
    /// Playing, which reads as the app forgetting what you did.
    private func rememberSection(from event: NotchEvent) {
        switch event {
        case .selectSection(let section), .attentionRequested(let section):
            config.defaultSection = section
        case .dropped:
            config.defaultSection = .fileShelf
        default:
            break
        }
    }

    /// Applies new timing/policy settings while preserving the remembered
    /// section, as long as that section is still available.
    func apply(config newConfig: NotchStateConfig, availableSections: [NotchSection]) {
        var merged = newConfig
        if availableSections.contains(config.defaultSection) {
            merged.defaultSection = config.defaultSection
        }
        config = merged
    }

    /// Cancels any pending timer and returns to `.collapsed` without animation
    /// bookkeeping. Used when the notch is hidden or the screen goes away.
    func reset() {
        pendingTimer?.cancel()
        pendingTimer = nil
        guard state != .collapsed else { return }
        state = .collapsed
        stateChanges.send(.collapsed)
    }

    /// True while a timer is outstanding. Exposed for tests only.
    var hasPendingTimer: Bool { pendingTimer != nil }
}
