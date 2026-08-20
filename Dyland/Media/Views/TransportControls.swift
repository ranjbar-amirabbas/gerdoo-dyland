import SwiftUI

/// Previous / play-pause / next.
struct TransportControls: View {

    let isPlaying: Bool
    let isEnabled: Bool
    let onPrevious: () -> Void
    let onTogglePlayPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            button("backward.fill", size: 12, label: "Previous track", action: onPrevious)
            button(isPlaying ? "pause.fill" : "play.fill",
                   size: 16,
                   label: isPlaying ? "Pause" : "Play",
                   action: onTogglePlayPause)
            button("forward.fill", size: 12, label: "Next track", action: onNext)
        }
        .opacity(isEnabled ? 1 : 0.35)
        .allowsHitTesting(isEnabled)
        // Explained rather than silently greyed out: without Automation
        // permission Dyland can read metadata but not send commands.
        .help(isEnabled ? "" : "Dyland needs Automation permission to control playback")
    }

    private func button(_ symbol: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(DesignTokens.primaryText)
                .frame(width: size + 12, height: size + 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
