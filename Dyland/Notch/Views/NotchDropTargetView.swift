import SwiftUI

/// Shown while a drag hovers the catch zone.
struct NotchDropTargetView: View {

    @EnvironmentObject private var shelf: FileShelfManager

    private var caption: String {
        shelf.isEmpty ? "Drop files to shelve them" : "Add to \(shelf.count) shelved"
    }

    var body: some View {
        RoundedRectangle(cornerRadius: DesignTokens.itemCornerRadius, style: .continuous)
            .strokeBorder(
                DesignTokens.dropTargetStroke,
                style: StrokeStyle(lineWidth: 1.5, dash: [5, 4])
            )
            .overlay {
                VStack(spacing: 6) {
                    Image(systemName: "tray.and.arrow.down")
                        .font(.system(size: 18, weight: .regular))
                    Text(caption)
                        .font(.system(size: 11))
                }
                .foregroundStyle(DesignTokens.secondaryText)
            }
            .accessibilityLabel("File drop target")
    }
}
