import Foundation

/// AppleScript sources used by `ScriptablePlayerProvider`.
///
/// Kept in one file so the scripting surface is auditable at a glance: Dyland
/// only ever *reads* state and sends the five transport verbs. It never
/// launches an application (every script assumes the target is already
/// running) and never writes to the user's library.
enum Scripts {

    /// ASCII unit separator — cannot occur in track metadata, so it is a safe
    /// field delimiter for the tuple the state script returns.
    static let separator = "\u{1F}"

    /// Returns `state` or `state␟title␟artist␟album␟duration␟position`.
    ///
    /// Playback state is compared against the enum constants rather than
    /// coerced to text: coercion spells the value differently across the two
    /// applications and across OS versions.
    static func state(for configuration: ScriptablePlayerConfiguration) -> String {
        """
        tell application "\(configuration.scriptingName)"
            set d to (ASCII character 31)
            set s to "stopped"
            if player state is playing then set s to "playing"
            if player state is paused then set s to "paused"
            if s is "stopped" then return s
            try
                set t to current track
                return s & d & (name of t as text) & d & (artist of t as text) & d & (album of t as text) & d & ((duration of t) as text) & d & ((player position) as text)
            on error
                return s
            end try
        end tell
        """
    }

    static func position(for configuration: ScriptablePlayerConfiguration) -> String {
        """
        tell application "\(configuration.scriptingName)"
            try
                return (player position) as text
            on error
                return ""
            end try
        end tell
        """
    }

    static func command(_ verb: String, for configuration: ScriptablePlayerConfiguration) -> String {
        """
        tell application "\(configuration.scriptingName)" to \(verb)
        """
    }

    static func artwork(for configuration: ScriptablePlayerConfiguration) -> String {
        switch configuration.artworkSource {
        case .embeddedData:
            return """
            tell application "\(configuration.scriptingName)"
                try
                    return (raw data of artwork 1 of current track)
                on error
                    return ""
                end try
            end tell
            """
        case .remoteURL:
            return """
            tell application "\(configuration.scriptingName)"
                try
                    return (artwork url of current track) as text
                on error
                    return ""
                end try
            end tell
            """
        case .unavailable:
            return "return \"\""
        }
    }
}
