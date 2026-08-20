import Foundation

/// Timing + policy inputs for the reducer. Supplied by `SettingsManager` at
/// runtime and by literals in tests, so transitions never read global state.
struct NotchStateConfig: Equatable, Sendable {
    var hoverExpansionEnabled: Bool = true
    /// Hover dwell before the notch opens.
    var expansionDelay: TimeInterval = 0.25
    /// Grace period after the pointer or drag leaves before collapsing.
    var collapseDelay: TimeInterval = 0.45
    /// How long a transient peek stays up.
    var previewDuration: TimeInterval = 2.0
    /// How long the shelf stays open after files land, so the user can grab them.
    var postDropDwell: TimeInterval = 3.0
    /// How long an attention request stays open.
    var attentionDwell: TimeInterval = 2.5
    /// Section opened when the user did not pick one explicitly.
    var defaultSection: NotchSection = .nowPlaying
}

/// A timer the machine wants running. `nil` in a transition means "cancel any
/// pending timer"; a value means "cancel any pending timer, then run this one".
struct ScheduledNotchEvent: Equatable, Sendable {
    var event: NotchEvent
    var delay: TimeInterval
}

struct NotchTransition: Equatable, Sendable {
    var state: NotchState
    var scheduled: ScheduledNotchEvent?
}

/// The single place a `NotchState` change is decided.
///
/// Pure and synchronous on purpose — the whole interaction model is unit
/// testable without a window, a run loop, or a clock.
enum NotchStateReducer {

    static func reduce(
        state: NotchState,
        event: NotchEvent,
        config: NotchStateConfig
    ) -> NotchTransition {
        switch event {

        case .hoverBegan:
            // A drag outranks hover: never downgrade an active drop target.
            guard state != .dragTarget else { return .init(state: state, scheduled: nil) }
            if state.isExpanded {
                // Pointer came back before the collapse timer fired.
                return .init(state: state, scheduled: nil)
            }
            guard config.hoverExpansionEnabled else {
                // Still show the hover affordance, just never auto-expand.
                return .init(state: .hovered, scheduled: nil)
            }
            return .init(
                state: .hovered,
                scheduled: .init(event: .expansionTimerFired, delay: config.expansionDelay)
            )

        case .expansionTimerFired:
            guard state == .hovered else { return .init(state: state, scheduled: nil) }
            return .init(state: .expanded(config.defaultSection), scheduled: nil)

        case .hoverEnded:
            guard state != .dragTarget else { return .init(state: state, scheduled: nil) }
            if state.isExpanded {
                return .init(
                    state: state,
                    scheduled: .init(event: .collapseTimerFired, delay: config.collapseDelay)
                )
            }
            if state == .hovered {
                return .init(state: .collapsed, scheduled: nil)
            }
            // `.mediaPreview` owns its own timer; leave it alone.
            return .init(state: state, scheduled: nil)

        case .collapseTimerFired:
            switch state {
            case .expanded, .dragTarget:
                return .init(state: .collapsed, scheduled: nil)
            case .collapsed, .hovered, .mediaPreview:
                return .init(state: state, scheduled: nil)
            }

        case .clicked:
            if state.isExpanded {
                return .init(state: .collapsed, scheduled: nil)
            }
            return .init(state: .expanded(config.defaultSection), scheduled: nil)

        case .dragEntered:
            return .init(state: .dragTarget, scheduled: nil)

        case .dragExited:
            guard state == .dragTarget else { return .init(state: state, scheduled: nil) }
            // Stay open briefly: drags routinely skim out and back in, and
            // collapsing on the first exit makes the target feel twitchy.
            return .init(
                state: .dragTarget,
                scheduled: .init(event: .collapseTimerFired, delay: config.collapseDelay)
            )

        case .dropped:
            return .init(
                state: .expanded(.fileShelf),
                scheduled: .init(event: .collapseTimerFired, delay: config.postDropDwell)
            )

        case .mediaChanged, .peekRequested:
            switch state {
            case .collapsed, .mediaPreview:
                return .init(
                    state: .mediaPreview,
                    scheduled: .init(event: .previewTimerFired, delay: config.previewDuration)
                )
            case .hovered, .expanded, .dragTarget:
                // Never yank the section out from under an engaged user.
                return .init(state: state, scheduled: nil)
            }

        case .previewTimerFired:
            guard state == .mediaPreview else { return .init(state: state, scheduled: nil) }
            return .init(state: .collapsed, scheduled: nil)

        case .attentionRequested(let section):
            guard state != .dragTarget else { return .init(state: state, scheduled: nil) }
            return .init(
                state: .expanded(section),
                scheduled: .init(event: .collapseTimerFired, delay: config.attentionDwell)
            )

        case .selectSection(let section):
            return .init(state: .expanded(section), scheduled: nil)

        case .dismiss:
            return .init(state: .collapsed, scheduled: nil)
        }
    }
}
