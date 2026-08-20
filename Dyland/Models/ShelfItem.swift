import Foundation
import UniformTypeIdentifiers

/// One file parked on the shelf.
///
/// The shelf stores **references only**. Dyland never copies, moves or writes
/// to the user's files; if the original is deleted or its volume is unmounted,
/// the item goes stale rather than silently pointing at nothing.
struct ShelfItem: Identifiable, Equatable, Sendable {

    let id: UUID
    /// Standardised, symlink-resolved location. Used for identity and dedupe.
    let url: URL
    let displayName: String
    let contentType: UTType?
    let isDirectory: Bool
    let addedAt: Date

    init(url: URL, addedAt: Date = Date(), id: UUID = UUID()) {
        let resolved = url.resolvingSymlinksInPath().standardizedFileURL
        self.id = id
        self.url = resolved
        self.addedAt = addedAt

        let values = try? resolved.resourceValues(forKeys: [
            .localizedNameKey, .contentTypeKey, .isDirectoryKey
        ])
        self.displayName = values?.localizedName ?? resolved.lastPathComponent
        self.contentType = values?.contentType
        self.isDirectory = values?.isDirectory ?? false
    }

    /// Short, human-facing type label ("PNG image", "Folder"), or the extension
    /// when the type is unknown to the system.
    var typeDescription: String {
        if isDirectory { return "Folder" }
        if let description = contentType?.localizedDescription { return description }
        let ext = url.pathExtension
        return ext.isEmpty ? "File" : ext.uppercased()
    }

    /// Re-checked on demand: a shelf that lies about availability is worse than
    /// one that shows an item as unavailable.
    var isAccessible: Bool {
        FileManager.default.fileExists(atPath: url.path)
    }

    func hasExpired(now: Date, after interval: TimeInterval) -> Bool {
        now.timeIntervalSince(addedAt) >= interval
    }
}
