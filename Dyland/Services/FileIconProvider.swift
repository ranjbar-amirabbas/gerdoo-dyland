import AppKit
import Combine

/// Caches Finder icons for shelf items.
///
/// `NSWorkspace.icon(forFile:)` hits the icon services daemon; calling it from
/// a SwiftUI `body` would do so on every redraw, which is exactly the kind of
/// idle work this app is supposed to avoid.
@MainActor
final class FileIconProvider: ObservableObject {

    private let cache = NSCache<NSString, NSImage>()
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
        cache.countLimit = 128
    }

    func icon(for url: URL, size: CGFloat) -> NSImage {
        let key = "\(url.path)#\(Int(size))" as NSString
        if let cached = cache.object(forKey: key) { return cached }

        let icon = workspace.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        cache.setObject(icon, forKey: key)
        return icon
    }

    /// Called when items leave the shelf so the cache cannot grow unbounded
    /// over a long-running session.
    func evict(_ url: URL) {
        for size in [22, 28, 32, 36, 44, 48, 64] {
            cache.removeObject(forKey: "\(url.path)#\(size)" as NSString)
        }
    }
}
