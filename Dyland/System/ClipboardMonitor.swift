import AppKit
import Combine

/// Watches the general pasteboard.
///
/// **Why this polls.** `NSPasteboard` posts no change notification — there is
/// no public (or private) callback for "the clipboard changed". Comparing
/// `changeCount` on a timer is the only mechanism available. The cost is kept
/// honest: one wakeup per second, a 0.5s tolerance so the kernel can coalesce
/// it with other timers, and the timer exists *only* while the module is
/// enabled (see `start()`/`stop()`).
@MainActor
final class ClipboardMonitor: ObservableObject {

    @Published private(set) var entries: [ClipboardEntry] = []
    @Published private(set) var isRunning = false
    /// Timestamp of the most recent capture, used to decide whether a notch
    /// peek should show the clipboard or the current track.
    @Published private(set) var lastCaptureDate: Date?

    /// Raised on each new capture so the app can offer a brief peek.
    var onCapture: ((ClipboardEntry) -> Void)?

    let capacity: Int
    private let pasteboard: NSPasteboard
    private let interval: TimeInterval
    private var timer: Timer?
    private var lastChangeCount: Int

    init(
        pasteboard: NSPasteboard = .general,
        capacity: Int = 10,
        interval: TimeInterval = 1.0
    ) {
        self.pasteboard = pasteboard
        self.capacity = capacity
        self.interval = interval
        self.lastChangeCount = pasteboard.changeCount
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        // Adopt the current count so launching does not capture whatever
        // happened to be on the clipboard beforehand.
        lastChangeCount = pasteboard.changeCount

        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        timer.tolerance = interval * 0.5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        Log.clipboard.info("Clipboard monitoring started")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        timer?.invalidate()
        timer = nil
        Log.clipboard.info("Clipboard monitoring stopped")
    }

    func clear() {
        entries.removeAll()
        lastCaptureDate = nil
    }

    /// Puts an entry back on the pasteboard.
    ///
    /// The resulting change is ignored: re-copying should not push a duplicate
    /// onto the front of the history.
    func copyBack(_ entry: ClipboardEntry) {
        pasteboard.clearContents()
        switch entry.payload {
        case .text(let text):
            pasteboard.setString(text, forType: .string)
        case .files(let urls):
            pasteboard.writeObjects(urls as [NSURL])
        }
        lastChangeCount = pasteboard.changeCount
        Log.clipboard.debug("Restored a clipboard entry")
    }

    /// Exposed for tests; the timer is the only production caller.
    func poll() {
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        guard let payload = readPayload() else { return }
        let entry = ClipboardEntry(payload: payload)

        // Ignore an immediate repeat of the same content.
        if entries.first?.contentKey == entry.contentKey { return }

        entries.insert(entry, at: 0)
        if entries.count > capacity {
            entries.removeLast(entries.count - capacity)
        }
        lastCaptureDate = entry.capturedAt
        onCapture?(entry)
    }

    private func readPayload() -> ClipboardEntry.Payload? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           !urls.isEmpty {
            return .files(urls)
        }
        if let text = pasteboard.string(forType: .string), !text.isEmpty {
            return .text(text)
        }
        // Images, RTF, and everything else are out of scope for the MVP; the
        // change is acknowledged so it is not re-read next tick.
        return nil
    }
}
