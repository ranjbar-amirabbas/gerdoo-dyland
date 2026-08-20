import AppKit
import Combine

/// Starts and stops feature modules as their settings change.
///
/// Turning a module off must actually release its observers — a disabled
/// clipboard module with a live 1 Hz timer would be a lie. Centralising that
/// here keeps the on/off contract in one readable place.
@MainActor
final class ModuleCoordinator {

    private let settings: SettingsManager
    private let media: MediaManager
    private let clipboard: ClipboardMonitor
    private var cancellables = Set<AnyCancellable>()
    private var wakeObserver: NSObjectProtocol?

    init(settings: SettingsManager, media: MediaManager, clipboard: ClipboardMonitor) {
        self.settings = settings
        self.media = media
        self.clipboard = clipboard
    }

    func start() {
        // Push notifications from Music/Spotify are not replayed across sleep,
        // so the first thing to do on wake is re-read every provider.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.settings.nowPlayingEnabled else { return }
                Task { await self.media.refreshAll() }
            }
        }

        settings.$nowPlayingEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                enabled ? self.media.start() : self.media.stop()
            }
            .store(in: &cancellables)

        settings.$clipboardEnabled
            .removeDuplicates()
            .sink { [weak self] enabled in
                guard let self else { return }
                enabled ? self.clipboard.start() : self.clipboard.stop()
            }
            .store(in: &cancellables)
    }

    func stop() {
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        cancellables.removeAll()
        media.stop()
        clipboard.stop()
    }
}
