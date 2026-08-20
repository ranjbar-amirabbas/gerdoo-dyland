import AppKit
import SwiftUI

/// Drags every shelved file out at once.
///
/// SwiftUI's `.onDrag` / `.draggable` vend exactly one item provider, so a
/// multi-file drag has to go through AppKit's dragging session API. This view
/// is the only AppKit surface inside the shelf, and it owns its own mouse
/// events on purpose — it is a control, not an overlay on other content.
final class MultiFileDragHandleView: NSView {

    var urlsProvider: () -> [URL] = { [] }
    var iconProvider: ((URL) -> NSImage)?

    private static let iconSide: CGFloat = 44
    /// Horizontal offset between stacked drag images, so a multi-file drag
    /// visibly reads as more than one file.
    private static let fanStep: CGFloat = 10

    override func mouseDown(with event: NSEvent) {
        // Swallow the click; the drag starts on the first drag event.
    }

    override func mouseDragged(with event: NSEvent) {
        let urls = urlsProvider()
        guard !urls.isEmpty else { return }

        let origin = convert(event.locationInWindow, from: nil)
        let items = urls.enumerated().map { index, url -> NSDraggingItem in
            let item = NSDraggingItem(pasteboardWriter: url as NSURL)
            let frame = NSRect(
                x: origin.x - Self.iconSide / 2 + CGFloat(index) * Self.fanStep,
                y: origin.y - Self.iconSide / 2,
                width: Self.iconSide,
                height: Self.iconSide
            )
            item.setDraggingFrame(frame, contents: iconProvider?(url))
            return item
        }

        beginDraggingSession(with: items, event: event, source: self)
    }
}

extension MultiFileDragHandleView: NSDraggingSource {
    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        // Copy only: the shelf holds references and must never move the
        // user's originals.
        .copy
    }
}

struct MultiFileDragHandle: NSViewRepresentable {

    let urls: [URL]
    let icon: (URL) -> NSImage

    func makeNSView(context: Context) -> MultiFileDragHandleView {
        let view = MultiFileDragHandleView()
        view.iconProvider = icon
        return view
    }

    func updateNSView(_ nsView: MultiFileDragHandleView, context: Context) {
        // Captured lazily so the session always drags the current shelf, not
        // whatever it held when the view was made.
        let urls = self.urls
        nsView.urlsProvider = { urls }
        nsView.iconProvider = icon
    }
}
