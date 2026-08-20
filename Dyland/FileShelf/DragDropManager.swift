import AppKit

/// Turns a raw drop into shelf items and notch state.
///
/// Kept separate from `FileShelfManager` so the shelf stays a pure collection
/// and all the AppKit/pasteboard reasoning lives in one place.
@MainActor
final class DragDropManager {

    private let shelf: FileShelfManager
    private let stateMachine: NotchStateMachine
    private let settings: SettingsManager

    init(shelf: FileShelfManager, stateMachine: NotchStateMachine, settings: SettingsManager) {
        self.shelf = shelf
        self.stateMachine = stateMachine
        self.settings = settings
    }

    /// Whether a drag should be accepted at all. Declining here lets the drag
    /// fall through to the window underneath the panel.
    var acceptsDrops: Bool { settings.fileShelfEnabled }

    /// - Returns: true when at least one file was shelved, which is what tells
    ///   AppKit to show the "accepted" animation instead of the snap-back.
    func handleDrop(_ urls: [URL]) -> Bool {
        guard acceptsDrops else {
            Log.shelf.notice("Drop ignored: the File Shelf module is disabled")
            return false
        }

        let added = shelf.add(urls)
        guard !added.isEmpty else {
            // Everything was a duplicate or unreadable. The user still aimed at
            // the shelf, so show it rather than snapping shut.
            stateMachine.send(.attentionRequested(.fileShelf))
            return false
        }
        return true
    }
}
