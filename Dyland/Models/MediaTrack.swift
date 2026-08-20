import Foundation

/// A single piece of media, as reported by whichever provider is active.
struct MediaTrack: Equatable, Sendable, Identifiable {

    /// Provider-scoped stable identity. Providers that expose a persistent ID
    /// use it; the rest fall back to a title/artist/album digest, which is
    /// enough to tell "the track changed" from "the same track ticked on".
    let id: String
    var title: String
    var artist: String?
    var album: String?
    var duration: TimeInterval?

    init(id: String? = nil, title: String, artist: String? = nil, album: String? = nil, duration: TimeInterval? = nil) {
        self.id = id ?? "\(title)|\(artist ?? "")|\(album ?? "")"
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
    }

    var subtitle: String? {
        switch (artist, album) {
        case let (artist?, album?): return "\(artist) — \(album)"
        case let (artist?, nil): return artist
        case let (nil, album?): return album
        case (nil, nil): return nil
        }
    }
}

enum MediaPlaybackState: String, Equatable, Sendable {
    case stopped
    case paused
    case playing

    var isPlaying: Bool { self == .playing }
}

/// One provider's view of the world at a point in time.
///
/// Immutable and `Equatable` so the manager can drop no-op updates instead of
/// republishing them into SwiftUI.
struct MediaSnapshot: Equatable, Sendable {

    let providerID: String
    var track: MediaTrack?
    var playback: MediaPlaybackState
    /// Playhead at `capturedAt`, when the provider reports one.
    var position: TimeInterval?
    var capturedAt: Date

    init(
        providerID: String,
        track: MediaTrack? = nil,
        playback: MediaPlaybackState = .stopped,
        position: TimeInterval? = nil,
        capturedAt: Date = Date()
    ) {
        self.providerID = providerID
        self.track = track
        self.playback = playback
        self.position = position
        self.capturedAt = capturedAt
    }

    static func idle(providerID: String, at date: Date = Date()) -> MediaSnapshot {
        MediaSnapshot(providerID: providerID, track: nil, playback: .stopped, position: nil, capturedAt: date)
    }

    var hasTrack: Bool { track != nil }

    /// Where the playhead is *now*, extrapolated from the last report.
    ///
    /// This is why Dyland needs no playback timer: a provider that pushes a
    /// snapshot once per state change is enough for a smooth progress bar, and
    /// the UI redraws only while it is actually on screen.
    func position(at now: Date) -> TimeInterval? {
        guard let position else { return nil }
        guard playback.isPlaying else { return position }
        let elapsed = max(0, now.timeIntervalSince(capturedAt))
        guard let duration = track?.duration else { return position + elapsed }
        return min(position + elapsed, duration)
    }

    var progress: Double? {
        progress(at: Date())
    }

    func progress(at now: Date) -> Double? {
        guard let duration = track?.duration, duration > 0,
              let position = position(at: now) else { return nil }
        return min(max(position / duration, 0), 1)
    }
}
