import AppKit
import Combine

/// Watches for anything that can invalidate the notch's screen placement.
///
/// All three notifications can arrive in bursts (a dock/undock fires several
/// `didChangeScreenParameters` in a row), so callbacks are coalesced.
@MainActor
final class ScreenObserver {

    private var observers: [NSObjectProtocol] = []
    private var coalesceTask: Task<Void, Never>?
    private let debounceInterval: TimeInterval
    private let onChange: () -> Void

    init(debounceInterval: TimeInterval = 0.25, onChange: @escaping () -> Void) {
        self.debounceInterval = debounceInterval
        self.onChange = onChange
        start()
    }

    deinit {
        // Removing observers is safe from any thread; the tokens are captured
        // by value so this does not need main-actor isolation.
        let tokens = observers
        let task = coalesceTask
        task?.cancel()
        for token in tokens {
            NotificationCenter.default.removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    private func start() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter

        observers.append(
            NotificationCenter.default.addObserver(
                forName: NSApplication.didChangeScreenParametersNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedule(reason: "screen parameters") }
            }
        )

        observers.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.didWakeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedule(reason: "wake") }
            }
        )

        observers.append(
            workspaceCenter.addObserver(
                forName: NSWorkspace.activeSpaceDidChangeNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                MainActor.assumeIsolated { self?.schedule(reason: "space change") }
            }
        )
    }

    private func schedule(reason: String) {
        Log.notch.debug("Screen configuration change: \(reason, privacy: .public)")
        coalesceTask?.cancel()
        coalesceTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: UInt64(self.debounceInterval * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self.onChange()
        }
    }
}
