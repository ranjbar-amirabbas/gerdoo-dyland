import AppKit
import SwiftUI

/// Panel construction: the one place AppKit views, the SwiftUI hierarchy, and
/// the state machine are stitched together.
extension NotchWindowController {

    func buildPanel(with geometry: NotchGeometry) {
        let panel = NotchPanel(contentRect: geometry.windowFrame)

        let host = NotchHostView(frame: CGRect(origin: .zero, size: geometry.windowSize))
        host.autoresizingMask = [.width, .height]
        host.canAcceptDrops = { [weak self] in
            self?.environment.dragDrop.acceptsDrops ?? false
        }
        host.onHoverChanged = { [weak self] hovering in
            self?.environment.stateMachine.send(hovering ? .hoverBegan : .hoverEnded)
        }
        host.onDragEnteredZone = { [weak self] in
            self?.environment.stateMachine.send(.dragEntered)
        }
        host.onDragExitedZone = { [weak self] in
            self?.environment.stateMachine.send(.dragExited)
        }
        host.onDrop = { [weak self] urls in
            guard let self else { return false }
            let accepted = self.dropHandler?(urls) ?? false
            if accepted {
                self.environment.stateMachine.send(.dropped)
            } else {
                self.environment.stateMachine.send(.dragExited)
            }
            return accepted
        }

        let rootView = NotchRootView()
            .environmentObject(environment.stateMachine)
            .environmentObject(environment.geometryStore)
            .environmentObject(environment.settings)
            .environmentObject(environment.fileShelf)
            .environmentObject(environment.iconProvider)
            .environmentObject(environment.media)
            .environmentObject(environment.clipboard)
            .environmentObject(environment.quickActions)

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = host.bounds
        hosting.autoresizingMask = [.width, .height]
        // The hosting view must not paint a background or it would show as a
        // grey rectangle over the desktop.
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = .clear
        host.addSubview(hosting)

        panel.contentView = host

        self.panel = panel
        self.hostView = host
    }
}
