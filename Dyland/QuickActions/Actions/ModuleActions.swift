import Foundation

/// Empties the file shelf.
@MainActor
struct ClearShelfAction: QuickAction {

    let id = "clear-shelf"
    let title = "Empty Shelf"
    let icon = "tray.and.arrow.up"

    private let shelf: FileShelfManager

    init(shelf: FileShelfManager) {
        self.shelf = shelf
    }

    var isEnabled: Bool { !shelf.isEmpty }

    func execute() async throws {
        shelf.clear()
    }
}

/// Switches the notch to the clipboard history.
@MainActor
struct ShowClipboardAction: QuickAction {

    let id = "show-clipboard"
    let title = "Clipboard"
    let icon = "doc.on.clipboard"

    private let stateMachine: NotchStateMachine
    private let clipboard: ClipboardMonitor

    init(stateMachine: NotchStateMachine, clipboard: ClipboardMonitor) {
        self.stateMachine = stateMachine
        self.clipboard = clipboard
    }

    var isEnabled: Bool { clipboard.isRunning }

    func execute() async throws {
        stateMachine.send(.selectSection(.clipboard))
    }
}
