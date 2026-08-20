import Foundation

/// Everything that differs between two AppleScript-driven players.
///
/// Music and Spotify expose the same *shape* of information through different
/// notification names, dictionary keys and units, so one generic provider plus
/// two configurations beats two near-identical classes.
struct ScriptablePlayerConfiguration: Sendable {

    enum ArtworkSource: Sendable {
        /// Music returns the embedded image bytes directly.
        case embeddedData
        /// Spotify returns an https URL that has to be fetched.
        case remoteURL
        case unavailable
    }

    let id: String
    let displayName: String
    let bundleIdentifier: String
    /// Name used in `tell application "…"`.
    let scriptingName: String

    /// Distributed notification the app posts on every state change. This is
    /// what makes the provider push-based instead of polling.
    let playerStateNotification: Notification.Name

    // Keys inside that notification's userInfo.
    let stateKey: String
    let titleKey: String
    let artistKey: String
    let albumKey: String
    let trackIDKey: String?
    let durationKey: String?
    /// Divisor turning the notification's duration into seconds.
    let durationScale: Double
    /// Present only when the app reports the playhead in its notification.
    let positionKey: String?

    let artworkSource: ArtworkSource

    static let appleMusic = ScriptablePlayerConfiguration(
        id: "apple-music",
        displayName: "Music",
        bundleIdentifier: "com.apple.Music",
        scriptingName: "Music",
        playerStateNotification: Notification.Name("com.apple.Music.playerInfo"),
        stateKey: "Player State",
        titleKey: "Name",
        artistKey: "Artist",
        albumKey: "Album",
        trackIDKey: "PersistentID",
        durationKey: "Total Time",
        durationScale: 1000,          // Music reports milliseconds here
        positionKey: nil,             // …and never reports the playhead
        artworkSource: .embeddedData
    )

    static let spotify = ScriptablePlayerConfiguration(
        id: "spotify",
        displayName: "Spotify",
        bundleIdentifier: "com.spotify.client",
        scriptingName: "Spotify",
        playerStateNotification: Notification.Name("com.spotify.client.PlaybackStateChanged"),
        stateKey: "Player State",
        titleKey: "Name",
        artistKey: "Artist",
        albumKey: "Album",
        trackIDKey: "Track ID",
        durationKey: "Duration",
        durationScale: 1000,
        positionKey: "Playback Position",
        artworkSource: .remoteURL
    )

    /// Normalises the many spellings these apps use for playback state.
    func playbackState(from raw: String?) -> MediaPlaybackState {
        switch raw?.lowercased() {
        case "playing": return .playing
        case "paused": return .paused
        default: return .stopped
        }
    }
}
