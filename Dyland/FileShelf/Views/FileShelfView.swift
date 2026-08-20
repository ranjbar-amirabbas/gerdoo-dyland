import SwiftUI

/// The expanded File Shelf: a horizontal strip of shelved files.
struct FileShelfView: View {

    @EnvironmentObject private var shelf: FileShelfManager
    @EnvironmentObject private var icons: FileIconProvider

    var body: some View {
        if shelf.isEmpty {
            emptyState
        } else {
            VStack(spacing: 6) {
                strip
                footer
            }
            // Vanished files are noticed when the shelf is shown rather than on
            // a timer, so an idle shelf costs nothing.
            .onAppear { shelf.pruneUnreachable() }
        }
    }

    private var strip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(shelf.items) { item in
                    ShelfItemView(
                        item: item,
                        icon: icons.icon(for: item.url, size: 64),
                        onRemove: { shelf.remove(id: item.id) },
                        onReveal: { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                    )
                }
            }
            .padding(.horizontal, 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("^[\(shelf.count) file](inflect: true)")
                .font(.system(size: 10))
                .foregroundStyle(DesignTokens.tertiaryText)

            Spacer(minLength: 0)

            if shelf.count > 1 {
                dragAllChip
            }

            Button("Clear") { shelf.clear() }
                .buttonStyle(.plain)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DesignTokens.secondaryText)
                .accessibilityLabel("Clear the file shelf")
        }
    }

    /// Drags every shelved file at once. Sized to match its label so the
    /// AppKit handle sitting on top covers exactly the visible chip.
    private var dragAllChip: some View {
        Label("Drag all", systemImage: "square.stack.3d.up")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(DesignTokens.secondaryText)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(DesignTokens.controlBackground)
            )
            .overlay(
                MultiFileDragHandle(
                    urls: shelf.urls,
                    icon: { icons.icon(for: $0, size: 44) }
                )
            )
            .accessibilityLabel("Drag all \(shelf.count) files")
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "tray")
                .font(.system(size: 20, weight: .light))
            Text("Drop files here to keep them handy")
                .font(.system(size: 11))
        }
        .foregroundStyle(DesignTokens.tertiaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
