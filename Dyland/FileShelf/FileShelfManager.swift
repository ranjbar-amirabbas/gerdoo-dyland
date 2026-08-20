import Combine
import Foundation

/// Holds the files the user has parked on the notch.
///
/// Deliberately in-memory for the MVP: the shelf is a staging area for a drag
/// you are in the middle of, not a document store. Persisting it would need
/// security-scoped bookmarks and a stale-reference policy neither of which
/// earns its keep yet (see README).
@MainActor
final class FileShelfManager: ObservableObject {

    /// Newest first — the file you just dropped is the one you are about to
    /// pick back up.
    @Published private(set) var items: [ShelfItem] = []

    /// Optional automatic expiry. `nil` (the default) means items stay for the
    /// lifetime of the app.
    @Published var expiration: TimeInterval? {
        didSet {
            guard expiration != oldValue else { return }
            restartExpirationSweep()
        }
    }

    /// Upper bound so a stray multi-thousand-file drop cannot blow up memory or
    /// the shelf layout. Oldest items fall off the end.
    let capacity: Int

    private let iconProvider: FileIconProvider?
    private let fileManager: FileManager
    private var sweepTask: Task<Void, Never>?

    init(
        capacity: Int = 24,
        fileManager: FileManager = .default,
        iconProvider: FileIconProvider? = nil
    ) {
        self.capacity = capacity
        self.fileManager = fileManager
        self.iconProvider = iconProvider
    }

    deinit {
        sweepTask?.cancel()
    }

    var isEmpty: Bool { items.isEmpty }
    var count: Int { items.count }
    var urls: [URL] { items.map(\.url) }

    // MARK: - Mutation

    /// Adds every readable URL that is not already shelved.
    ///
    /// - Returns: the items actually added, in the order they were accepted.
    ///   An empty result means the drop contributed nothing new.
    @discardableResult
    func add(_ urls: [URL], now: Date = Date()) -> [ShelfItem] {
        var added: [ShelfItem] = []

        for url in urls {
            let candidate = ShelfItem(url: url, addedAt: now)

            guard fileManager.fileExists(atPath: candidate.url.path) else {
                Log.shelf.error("Refusing unreachable drop: \(candidate.url.path, privacy: .public)")
                continue
            }
            guard fileManager.isReadableFile(atPath: candidate.url.path) else {
                // Happens with files in another user's home or on a volume the
                // app has no permission for. Surfaced, not swallowed.
                Log.shelf.error("Refusing unreadable drop: \(candidate.url.path, privacy: .public)")
                continue
            }
            guard !items.contains(where: { $0.url == candidate.url }) else {
                Log.shelf.debug("Already shelved: \(candidate.url.lastPathComponent, privacy: .public)")
                continue
            }

            added.append(candidate)
        }

        guard !added.isEmpty else { return [] }

        items.insert(contentsOf: added, at: 0)
        enforceCapacity()
        Log.shelf.info("Shelved \(added.count) item(s); shelf now holds \(self.items.count)")
        return added
    }

    func remove(id: ShelfItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let removed = items.remove(at: index)
        iconProvider?.evict(removed.url)
    }

    func remove(ids: Set<ShelfItem.ID>) {
        guard !ids.isEmpty else { return }
        for item in items where ids.contains(item.id) {
            iconProvider?.evict(item.url)
        }
        items.removeAll { ids.contains($0.id) }
    }

    func clear() {
        guard !items.isEmpty else { return }
        for item in items { iconProvider?.evict(item.url) }
        items.removeAll()
        Log.shelf.info("Shelf cleared")
    }

    /// Drops items whose backing file has disappeared. Cheap enough to call
    /// when the shelf becomes visible; never called on a timer.
    @discardableResult
    func pruneUnreachable() -> Int {
        let before = items.count
        items.removeAll { item in
            let gone = !fileManager.fileExists(atPath: item.url.path)
            if gone {
                Log.shelf.notice("Dropping vanished item: \(item.url.lastPathComponent, privacy: .public)")
                iconProvider?.evict(item.url)
            }
            return gone
        }
        return before - items.count
    }

    /// Removes items older than `expiration`. Exposed (with an injectable
    /// clock) so expiry can be tested without waiting.
    @discardableResult
    func pruneExpired(now: Date = Date()) -> Int {
        guard let expiration else { return 0 }
        let before = items.count
        items.removeAll { item in
            let expired = item.hasExpired(now: now, after: expiration)
            if expired { iconProvider?.evict(item.url) }
            return expired
        }
        return before - items.count
    }

    // MARK: - Private

    private func enforceCapacity() {
        guard items.count > capacity else { return }
        let overflow = items[capacity...]
        for item in overflow { iconProvider?.evict(item.url) }
        items.removeLast(items.count - capacity)
        Log.shelf.notice("Shelf capacity \(self.capacity) exceeded; oldest items dropped")
    }

    /// The sweep task exists only while an expiration is configured, so the
    /// default configuration has no timer at all.
    private func restartExpirationSweep() {
        sweepTask?.cancel()
        sweepTask = nil

        guard let expiration, expiration > 0 else { return }
        // Check at a quarter of the expiry, bounded so a long expiry does not
        // mean a long wait for the first sweep.
        let interval = min(max(expiration / 4, 5), 60)

        sweepTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self?.pruneExpired()
            }
        }
    }
}
