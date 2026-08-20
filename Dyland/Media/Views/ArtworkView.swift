import SwiftUI

/// Album art with a graceful placeholder.
///
/// Artwork is optional everywhere in Dyland: Spotify serves it over the
/// network, Music may have none embedded, and a provider without Automation
/// permission has none at all. None of those is an error state.
struct ArtworkView: View {

    let image: NSImage?
    var side: CGFloat = 56
    var cornerRadius: CGFloat = 8

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder
            }
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
    }

    private var placeholder: some View {
        ZStack {
            DesignTokens.controlBackground
            Image(systemName: "music.note")
                .font(.system(size: side * 0.36, weight: .light))
                .foregroundStyle(DesignTokens.tertiaryText)
        }
    }
}
