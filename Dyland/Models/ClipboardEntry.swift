import AppKit

/// One captured clipboard item.
///
/// Scope is deliberately small: text and file URLs, held in memory, capped at a
/// handful of entries. Dyland is not a clipboard manager and does not persist
/// anything the user copied to disk.
struct ClipboardEntry: Identifiable, Equatable, Sendable {

    enum Payload: Equatable, Sendable {
        case text(String)
        case files([URL])
    }

    let id: UUID
    let payload: Payload
    let capturedAt: Date

    init(payload: Payload, capturedAt: Date = Date(), id: UUID = UUID()) {
        self.payload = payload
        self.capturedAt = capturedAt
        self.id = id
    }

    /// Single-line summary for the notch, collapsed whitespace and all.
    var preview: String {
        switch payload {
        case .text(let text):
            let flattened = text
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            return flattened.isEmpty ? "(whitespace)" : flattened
        case .files(let urls):
            guard let first = urls.first else { return "(no files)" }
            return urls.count == 1
                ? first.lastPathComponent
                : "\(first.lastPathComponent) +\(urls.count - 1)"
        }
    }

    var symbolName: String {
        switch payload {
        case .text: return "text.alignleft"
        case .files: return "doc.on.doc"
        }
    }

    /// Identity for de-duplication: copying the same thing twice in a row
    /// should not add a second entry.
    var contentKey: String {
        switch payload {
        case .text(let text): return "t:\(text)"
        case .files(let urls): return "f:\(urls.map(\.path).joined(separator: "|"))"
        }
    }
}
