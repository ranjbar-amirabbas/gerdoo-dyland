import SwiftUI

/// Recent clipboard entries, newest first. Clicking one puts it back on the
/// pasteboard.
struct ClipboardView: View {

    @EnvironmentObject private var clipboard: ClipboardMonitor

    var body: some View {
        if clipboard.entries.isEmpty {
            emptyState
        } else {
            list
        }
    }

    private var list: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 3) {
                ForEach(clipboard.entries) { entry in
                    ClipboardRow(entry: entry) { clipboard.copyBack(entry) }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 20, weight: .light))
            Text(clipboard.isRunning ? "Copy something to see it here" : "Clipboard monitoring is off")
                .font(.system(size: 11))
        }
        .foregroundStyle(DesignTokens.tertiaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct ClipboardRow: View {

    let entry: ClipboardEntry
    let onCopy: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 8) {
                Image(systemName: entry.symbolName)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignTokens.tertiaryText)
                    .frame(width: 14)

                Text(entry.preview)
                    .font(.system(size: 11))
                    .foregroundStyle(DesignTokens.primaryText)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)

                if isHovering {
                    Image(systemName: "arrow.up.doc.on.clipboard")
                        .font(.system(size: 9))
                        .foregroundStyle(DesignTokens.secondaryText)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isHovering ? DesignTokens.controlBackgroundHover : DesignTokens.controlBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel("Copy again: \(entry.preview)")
    }
}
