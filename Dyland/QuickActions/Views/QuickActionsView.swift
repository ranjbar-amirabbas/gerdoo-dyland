import SwiftUI

/// Grid of quick actions.
struct QuickActionsView: View {

    @EnvironmentObject private var manager: QuickActionManager
    // Some actions derive `isEnabled` from other modules (Empty Shelf from the
    // shelf, Clipboard from the monitor). Observing them here is what redraws
    // the grid when those modules change.
    @EnvironmentObject private var shelf: FileShelfManager
    @EnvironmentObject private var clipboard: ClipboardMonitor

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 8)]

    var body: some View {
        VStack(spacing: 6) {
            Spacer(minLength: 0)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(manager.actions, id: \.id) { action in
                    QuickActionButton(action: action) {
                        Task { await manager.run(action) }
                    }
                }
            }

            if let message = manager.lastErrorMessage {
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.yellow)
                    .lineLimit(2)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .animation(.easeOut(duration: 0.15), value: manager.lastErrorMessage)
    }
}

private struct QuickActionButton: View {

    let action: any QuickAction
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // SF Symbols have wildly different bounding boxes; a fixed
                // height keeps every label on the same baseline.
                Image(systemName: action.icon)
                    .font(.system(size: 15, weight: .regular))
                    .frame(height: 18)
                Text(action.title)
                    .font(.system(size: 9))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.itemCornerRadius, style: .continuous)
                    .fill(isHovering && action.isEnabled
                          ? DesignTokens.controlBackgroundHover
                          : DesignTokens.controlBackground)
            )
            .foregroundStyle(action.isEnabled ? DesignTokens.primaryText : DesignTokens.tertiaryText)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!action.isEnabled)
        .onHover { isHovering = $0 }
        .accessibilityLabel(action.title)
    }
}
