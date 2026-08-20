import SwiftUI

/// What a peek is showing. Clipboard captures and track changes share the
/// widened pill; whichever happened most recently wins.
enum NotchPeekContent: Equatable {
    case media(artwork: NSImage?, isPlaying: Bool)
    case clipboard(summary: String, symbol: String)
    case none
}

/// The widened collapsed pill: indicators sit either side of the camera
/// housing, since anything drawn *behind* the housing is invisible.
struct NotchPeekView: View {

    let notchWidth: CGFloat
    let content: NotchPeekContent
    let showWaveform: Bool
    /// False under Reduce Motion or when animations are turned off; the bars
    /// then hold a frozen pattern instead of pulsing.
    var animatesWaveform: Bool = true

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(maxWidth: .infinity)
            // The dead zone under the housing.
            Color.clear.frame(width: notchWidth)
            trailing.frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var leading: some View {
        switch content {
        case .media(let artwork, _):
            ArtworkView(image: artwork, side: 18, cornerRadius: 4)
        case .clipboard(_, let symbol):
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch content {
        case .media(_, let isPlaying):
            if showWaveform {
                WaveformView(barCount: 4, isAnimating: isPlaying && animatesWaveform)
                    .frame(width: 20, height: 12)
            } else {
                Image(systemName: isPlaying ? "waveform" : "pause.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(DesignTokens.secondaryText)
            }
        case .clipboard(let summary, _):
            Text(summary)
                .font(.system(size: 9))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
                .truncationMode(.tail)
        case .none:
            EmptyView()
        }
    }
}
