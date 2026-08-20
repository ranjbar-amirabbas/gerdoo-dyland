import SwiftUI

/// One file chip on the shelf.
struct ShelfItemView: View {

    let item: ShelfItem
    let icon: NSImage
    let onRemove: () -> Void
    let onReveal: () -> Void

    @State private var isHovering = false

    private let side: CGFloat = 64

    var body: some View {
        VStack(spacing: 4) {
            iconStack
            Text(item.displayName)
                .font(.system(size: 9))
                .foregroundStyle(DesignTokens.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: side)
        }
        .opacity(item.isAccessible ? 1 : 0.45)
        .onHover { isHovering = $0 }
        // The whole chip is the drag source: `NSItemProvider(contentsOf:)`
        // registers the file's real type, which is what makes Mail and browsers
        // accept the drop rather than pasting a path string.
        .onDrag {
            NSItemProvider(contentsOf: item.url) ?? NSItemProvider()
        } preview: {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 48, height: 48)
        }
        .contextMenu {
            Button("Reveal in Finder", action: onReveal)
            Button("Remove from Shelf", action: onRemove)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.displayName), \(item.typeDescription)")
        .accessibilityHint(item.isAccessible ? "Drag to another app to copy" : "File is no longer available")
    }

    private var iconStack: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: DesignTokens.itemCornerRadius, style: .continuous)
                .fill(DesignTokens.controlBackground)
                .frame(width: side, height: side)
                .overlay {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 34, height: 34)
                }

            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(Color.white, Color.black.opacity(0.75))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .transition(.opacity)
                .accessibilityLabel("Remove \(item.displayName)")
            }

            if !item.isAccessible {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.yellow)
                    .offset(x: 4, y: -4)
                    .help("The original file is no longer available")
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}
