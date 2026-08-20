import SwiftUI

/// The expanded Now Playing module.
struct NowPlayingView: View {

    @EnvironmentObject private var media: MediaManager
    @EnvironmentObject private var settings: SettingsManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let snapshot = media.snapshot, let track = snapshot.track {
            playing(snapshot: snapshot, track: track)
        } else {
            idle
        }
    }

    private func playing(snapshot: MediaSnapshot, track: MediaTrack) -> some View {
        HStack(spacing: DesignTokens.contentSpacing) {
            ArtworkView(image: media.artwork, side: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(1)

                if let subtitle = track.subtitle {
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(DesignTokens.secondaryText)
                        .lineLimit(1)
                }

                if snapshot.progress != nil {
                    PlaybackProgressView(snapshot: snapshot)
                        .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 6) {
                TransportControls(
                    isPlaying: snapshot.playback.isPlaying,
                    isEnabled: media.activeProvider != nil,
                    onPrevious: { Task { await media.previousTrack() } },
                    onTogglePlayPause: { Task { await media.togglePlayPause() } },
                    onNext: { Task { await media.nextTrack() } }
                )

                if settings.showWaveform {
                    WaveformView(
                        barCount: 5,
                        isAnimating: snapshot.playback.isPlaying && !reduceMotion
                            && settings.animationIntensity != .none
                    )
                        .frame(width: 34, height: 16)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(track.title)\(track.artist.map { " by \($0)" } ?? "")")
    }

    private var idle: some View {
        VStack(spacing: 6) {
            Image(systemName: media.isAvailable ? "music.note" : "music.note.list")
                .font(.system(size: 20, weight: .light))
            Text(idleMessage)
                .font(.system(size: 11))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(DesignTokens.tertiaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Distinguishes "nothing is playing" from "there is nothing that *could*
    /// play", because the fix is different in each case.
    private var idleMessage: String {
        media.isAvailable
            ? "Nothing playing"
            : "Install Music or Spotify to see Now Playing"
    }
}
