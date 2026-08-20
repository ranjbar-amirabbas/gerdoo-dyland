import SwiftUI

/// Playhead bar with elapsed / remaining labels.
///
/// The bar redraws on a 0.5s timeline **only while playing**, and the position
/// itself is extrapolated from the last provider snapshot, so nothing polls the
/// music app to keep this moving.
struct PlaybackProgressView: View {

    let snapshot: MediaSnapshot

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let now = snapshot.playback.isPlaying ? context.date : snapshot.capturedAt
            VStack(spacing: 3) {
                bar(progress: snapshot.progress(at: now) ?? 0)
                labels(at: now)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Playback position")
        .accessibilityValue(Self.format(snapshot.position(at: Date())) ?? "unknown")
    }

    private func bar(progress: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(DesignTokens.controlBackground)
                Capsule()
                    .fill(DesignTokens.accent)
                    .frame(width: max(0, proxy.size.width * progress))
            }
        }
        .frame(height: 3)
    }

    @ViewBuilder
    private func labels(at now: Date) -> some View {
        if let elapsed = Self.format(snapshot.position(at: now)) {
            HStack {
                Text(elapsed)
                Spacer(minLength: 0)
                if let remaining = Self.formatRemaining(snapshot, at: now) {
                    Text(remaining)
                }
            }
            .font(.system(size: 9, weight: .regular).monospacedDigit())
            .foregroundStyle(DesignTokens.tertiaryText)
        }
    }

    private static func format(_ interval: TimeInterval?) -> String? {
        guard let interval, interval.isFinite, interval >= 0 else { return nil }
        let total = Int(interval.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private static func formatRemaining(_ snapshot: MediaSnapshot, at now: Date) -> String? {
        guard let duration = snapshot.track?.duration,
              let position = snapshot.position(at: now) else { return nil }
        return format(max(0, duration - position)).map { "-\($0)" }
    }
}
