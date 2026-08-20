import AppKit

/// The borderless, transparent window that hosts the notch UI.
///
/// AppKit notes worth keeping:
///  * `.nonactivatingPanel` lets the user interact without Dyland stealing
///    focus from whatever they were doing — essential for a notch utility.
///  * The level must sit above `.mainMenu` (24) to draw over the menu bar and
///    the camera housing; `.statusBar + 1` is the lowest level that does.
///  * `canBecomeKey` stays false so no text field in another app loses focus.
///    SwiftUI buttons still receive clicks in a non-key panel.
final class NotchPanel: NSPanel {

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false          // the SwiftUI body draws its own shadow
        isMovable = false
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        hidesOnDeactivate = false
        ignoresMouseEvents = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

        // Follow the user across Spaces and stay put during fullscreen
        // transitions. `.ignoresCycle` keeps us out of Cmd+` cycling.
        collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .stationary,
            .ignoresCycle
        ]

        // Borderless panels are excluded from window restoration; being explicit
        // avoids a stale frame being restored onto a display that is gone.
        isRestorable = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    override var acceptsFirstResponder: Bool { false }
}
