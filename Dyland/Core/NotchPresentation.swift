import Foundation

/// How much room the notch body currently occupies.
///
/// Separate from `NotchState` because two different states can share a size: a
/// collapsed notch with music playing and an explicit media peek both render at
/// `.peek`. Keeping size out of the state enum stops the state machine from
/// having to know anything about media.
enum NotchPresentation: String, Equatable, Sendable {
    /// Exactly the physical notch — invisible on a notched Mac.
    case collapsed
    /// Slightly wider, so indicators can sit either side of the camera housing.
    case peek
    /// The full panel.
    case open
}

enum NotchPresentationResolver {

    /// - Parameters:
    ///   - hasMedia: a track is loaded (playing or paused).
    ///   - waveformEnabled: the user's "show waveform" preference; when off,
    ///     a collapsed notch never widens for media.
    static func resolve(
        state: NotchState,
        hasMedia: Bool,
        waveformEnabled: Bool
    ) -> NotchPresentation {
        if state.isOpen { return .open }

        switch state {
        case .mediaPreview:
            // An explicit peek always widens, even with the waveform disabled:
            // the point of the peek is to show what changed.
            return .peek
        case .collapsed, .hovered:
            return (hasMedia && waveformEnabled) ? .peek : .collapsed
        case .expanded, .dragTarget:
            return .open
        }
    }
}
