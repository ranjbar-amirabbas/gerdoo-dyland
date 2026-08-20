import AppKit
import UniformTypeIdentifiers

/// AppKit backing view for the notch panel.
///
/// It exists for two things SwiftUI cannot express on a borderless panel:
///
///  1. **Selective hit testing.** The panel is always as large as the fully
///     expanded UI. Without an override, that transparent rectangle would
///     swallow every click in the top-centre of the screen. `hitTest` therefore
///     rejects points outside the region the notch currently occupies.
///  2. **A drag catch zone.** macOS exposes no way to observe a drag before it
///     reaches one of your windows, so the panel registers a generous catch
///     zone and expands the moment a drag enters it.
final class NotchHostView: NSView {

    /// Region that currently accepts clicks, in this view's flipped space.
    var interactiveRect: CGRect = .zero {
        didSet {
            guard interactiveRect != oldValue else { return }
            updateTrackingAreas()
        }
    }

    /// Region that accepts drags. Larger than `interactiveRect` on purpose.
    var dragCatchZone: CGRect = .zero

    /// Consulted before a drag is accepted. Returning false makes the panel
    /// transparent to drags, which is what "File Shelf disabled" must mean.
    var canAcceptDrops: () -> Bool = { true }

    var onHoverChanged: ((Bool) -> Void)?
    var onDragEnteredZone: (() -> Void)?
    var onDragExitedZone: (() -> Void)?
    /// Returns true when the URLs were accepted.
    var onDrop: (([URL]) -> Bool)?

    private var hoverTrackingArea: NSTrackingArea?
    private var isHovering = false
    private var isDragInsideZone = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("NotchHostView is created programmatically only")
    }

    /// Flipped so view coordinates match SwiftUI's top-left origin, which is
    /// how every rect in `NotchGeometry` is expressed.
    override var isFlipped: Bool { true }

    // MARK: - Hit testing

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        guard interactiveRect.contains(local) else { return nil }
        return super.hitTest(point)
    }

    // MARK: - Hover

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = hoverTrackingArea {
            removeTrackingArea(existing)
            hoverTrackingArea = nil
        }

        guard !interactiveRect.isEmpty else { return }

        // `.activeAlways` is what makes hover work while another app is
        // frontmost — without it a non-activating panel never sees the mouse.
        //
        // `.mouseMoved` is belt-and-braces: rebuilding a tracking area while
        // the pointer is moving can drop the `mouseEntered` that would have
        // followed, which would strand the notch in the wrong hover state.
        // These events only fire while the pointer is already inside the rect.
        let area = NSTrackingArea(
            rect: interactiveRect,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        hoverTrackingArea = area

        // Replacing a tracking area does not synthesise enter/exit events, so a
        // resize that moves the region out from under the pointer would leave
        // us stuck in `.hovered`. Reconcile explicitly.
        reconcileHoverState()
    }

    private func reconcileHoverState() {
        guard let window else { return }
        let inWindow = window.mouseLocationOutsideOfEventStream
        let local = convert(inWindow, from: nil)
        setHovering(interactiveRect.contains(local))
    }

    private func setHovering(_ hovering: Bool) {
        guard hovering != isHovering else { return }
        isHovering = hovering
        onHoverChanged?(hovering)
    }

    override func mouseEntered(with event: NSEvent) {
        setHovering(true)
    }

    override func mouseExited(with event: NSEvent) {
        setHovering(false)
    }

    override func mouseMoved(with event: NSEvent) {
        // Cheap: `setHovering` is a no-op once the state already matches.
        setHovering(interactiveRect.contains(convert(event.locationInWindow, from: nil)))
    }

    // MARK: - Drag destination

    /// Returning `[]` means "not a destination", which lets the drag fall
    /// through to whatever window is underneath — important, because this panel
    /// covers a strip of every app's title bar area.
    private func operation(for info: NSDraggingInfo) -> NSDragOperation {
        guard canAcceptDrops() else { return [] }
        let local = convert(info.draggingLocation, from: nil)
        guard dragCatchZone.contains(local), info.hasFileURLs else { return [] }
        return .copy
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let op = operation(for: sender)
        updateZoneState(isInside: !op.isEmpty)
        return op
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        let op = operation(for: sender)
        updateZoneState(isInside: !op.isEmpty)
        return op
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        updateZoneState(isInside: false)
    }

    override func draggingEnded(_ sender: NSDraggingInfo) {
        updateZoneState(isInside: false)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        !operation(for: sender).isEmpty
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.fileURLs
        guard !urls.isEmpty else {
            Log.shelf.error("Drop contained no readable file URLs")
            return false
        }
        return onDrop?(urls) ?? false
    }

    private func updateZoneState(isInside: Bool) {
        guard isInside != isDragInsideZone else { return }
        isDragInsideZone = isInside
        if isInside {
            onDragEnteredZone?()
        } else {
            onDragExitedZone?()
        }
    }
}

extension NSDraggingInfo {

    /// File URLs carried by the drag, or an empty array.
    var fileURLs: [URL] {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        let objects = draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options)
        return (objects as? [URL]) ?? []
    }

    var hasFileURLs: Bool {
        draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }
}
