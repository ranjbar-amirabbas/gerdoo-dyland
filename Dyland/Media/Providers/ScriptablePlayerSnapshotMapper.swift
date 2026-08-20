import Foundation

/// Turns a player's raw output into a `MediaSnapshot`.
///
/// Extracted from `ScriptablePlayerProvider` because this is where the fiddly,
/// bug-prone details live — Music and Spotify disagree about units, key names,
/// and what they send when nothing is loaded — and because pure functions are
/// the only part of the media stack that can be tested without a running app.
enum ScriptablePlayerSnapshotMapper {

    /// Builds a snapshot from a distributed notification's `userInfo`.
    ///
    /// Returns an idle snapshot when the player is stopped or the payload has
    /// no usable title, which is what both apps send on "playback ended".
    static func snapshot(
        configuration: ScriptablePlayerConfiguration,
        userInfo: [AnyHashable: Any],
        now: Date = Date()
    ) -> MediaSnapshot {
        let state = configuration.playbackState(from: userInfo[configuration.stateKey] as? String)

        guard state != .stopped,
              let title = userInfo[configuration.titleKey] as? String,
              !title.isEmpty else {
            return .idle(providerID: configuration.id, at: now)
        }

        let duration = (userInfo[configuration.durationKey ?? ""] as? NSNumber)
            .map { $0.doubleValue / configuration.durationScale }
        let position = (userInfo[configuration.positionKey ?? ""] as? NSNumber)?.doubleValue
        let trackID = (userInfo[configuration.trackIDKey ?? ""] as? String)
            .map { "\(configuration.id):\($0)" }

        return MediaSnapshot(
            providerID: configuration.id,
            track: MediaTrack(
                id: trackID,
                title: title,
                artist: nonEmpty(userInfo[configuration.artistKey] as? String),
                album: nonEmpty(userInfo[configuration.albumKey] as? String),
                duration: duration
            ),
            playback: state,
            position: position,
            capturedAt: now
        )
    }

    /// Parses the unit-separated tuple produced by `Scripts.state`:
    /// `state␟title␟artist␟album␟duration␟position`, or just `state` when
    /// nothing is loaded.
    static func snapshot(
        configuration: ScriptablePlayerConfiguration,
        scriptResult raw: String,
        now: Date = Date()
    ) -> MediaSnapshot {
        let fields = raw.components(separatedBy: Scripts.separator)
        let state = configuration.playbackState(from: fields.first)

        guard state != .stopped, fields.count >= 6 else {
            return .idle(providerID: configuration.id, at: now)
        }

        return MediaSnapshot(
            providerID: configuration.id,
            track: MediaTrack(
                title: fields[1],
                artist: nonEmpty(fields[2]),
                album: nonEmpty(fields[3]),
                duration: Double(fields[4]).map { $0 / configuration.scriptDurationScale }
            ),
            playback: state,
            position: Double(fields[5]),
            capturedAt: now
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
