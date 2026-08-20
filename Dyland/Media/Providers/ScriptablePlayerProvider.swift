import AppKit
import Combine

/// Push-based provider for AppleScript-controllable players (Music, Spotify).
///
/// How it stays cheap and permission-light:
///  * **No polling.** Both apps post a distributed notification on every state
///    change; that notification is the only trigger.
///  * **Metadata needs no permission.** Title/artist/album/duration come out of
///    the notification's `userInfo`, which any process can receive.
///  * **Only transport and the playhead need Automation permission.** If the
///    user declines it, Now Playing still shows what is playing — the buttons
///    and the progress bar are what degrade, and that is logged once.
@MainActor
final class ScriptablePlayerProvider: MediaProvider {

    let configuration: ScriptablePlayerConfiguration
    /// Module-internal rather than private so the artwork extension in the
    /// neighbouring file can reach it.
    let runner: AppleScriptRunner
    private let workspace: NSWorkspace
    private let subject: CurrentValueSubject<MediaSnapshot, Never>

    private var observers: [NSObjectProtocol] = []
    private var isStarted = false
    /// Automation refusals are logged once per launch, not once per event.
    /// Internal so the transport/artwork extensions can consult it.
    var hasWarnedAboutPermission = false

    init(
        configuration: ScriptablePlayerConfiguration,
        runner: AppleScriptRunner = AppleScriptRunner(),
        workspace: NSWorkspace = .shared
    ) {
        self.configuration = configuration
        self.runner = runner
        self.workspace = workspace
        self.subject = CurrentValueSubject(.idle(providerID: configuration.id))
    }

    deinit {
        let tokens = observers
        for token in tokens {
            DistributedNotificationCenter.default().removeObserver(token)
            NSWorkspace.shared.notificationCenter.removeObserver(token)
        }
    }

    // MARK: - MediaProvider

    var id: String { configuration.id }
    var displayName: String { configuration.displayName }

    var isInstalled: Bool {
        workspace.urlForApplication(withBundleIdentifier: configuration.bundleIdentifier) != nil
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: configuration.bundleIdentifier).isEmpty
    }

    var snapshots: AnyPublisher<MediaSnapshot, Never> { subject.eraseToAnyPublisher() }
    var currentSnapshot: MediaSnapshot { subject.value }

    func start() {
        guard !isStarted, isInstalled else { return }
        isStarted = true

        observers.append(
            DistributedNotificationCenter.default().addObserver(
                forName: configuration.playerStateNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated { self?.handle(notification) }
            }
        )

        // Quitting the player leaves no notification behind, so watch the
        // workspace as well or the notch would show a ghost track forever.
        observers.append(
            workspace.notificationCenter.addObserver(
                forName: NSWorkspace.didTerminateApplicationNotification,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                MainActor.assumeIsolated { self?.handleTermination(notification) }
            }
        )

        Log.media.info("\(self.configuration.displayName, privacy: .public) provider started")
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        for token in observers {
            DistributedNotificationCenter.default().removeObserver(token)
            workspace.notificationCenter.removeObserver(token)
        }
        observers.removeAll()
        subject.send(.idle(providerID: id))
    }

    func refresh() async {
        guard isInstalled else { return }
        guard isRunning else {
            // Not an error: Dyland must never launch a music app by itself.
            emitIdleIfNeeded()
            return
        }

        do {
            let raw = try await runner.runReturningString(Scripts.state(for: configuration))
            subject.send(ScriptablePlayerSnapshotMapper.snapshot(configuration: configuration, scriptResult: raw))
        } catch AppleScriptRunner.Failure.targetNotRunning {
            emitIdleIfNeeded()
        } catch AppleScriptRunner.Failure.permissionDenied {
            warnAboutPermissionOnce()
        } catch {
            Log.media.error("\(self.configuration.displayName, privacy: .public) refresh failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Notification handling

    private func handle(_ notification: Notification) {
        guard let info = notification.userInfo else {
            // Some builds post without a payload; fall back to a script read.
            Task { await refresh() }
            return
        }

        subject.send(ScriptablePlayerSnapshotMapper.snapshot(configuration: configuration, userInfo: info))

        // The notification never carries the playhead for Music, and Spotify's
        // can lag a seek, so top it up with one script read (never a loop).
        Task { await refreshPositionOnly() }
    }

    private func handleTermination(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        guard app?.bundleIdentifier == configuration.bundleIdentifier else { return }
        Log.media.info("\(self.configuration.displayName, privacy: .public) quit; clearing its state")
        subject.send(.idle(providerID: id))
    }

    // MARK: - Scripting

    private func refreshPositionOnly() async {
        guard isRunning else { return }
        do {
            let raw = try await runner.runReturningString(Scripts.position(for: configuration))
            guard let position = Double(raw.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
            var snapshot = subject.value
            guard snapshot.hasTrack else { return }
            snapshot.position = position
            snapshot.capturedAt = Date()
            subject.send(snapshot)
        } catch AppleScriptRunner.Failure.permissionDenied {
            warnAboutPermissionOnce()
        } catch AppleScriptRunner.Failure.targetNotRunning {
            emitIdleIfNeeded()
        } catch {
            Log.media.debug("Playhead read failed for \(self.configuration.displayName, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private func emitIdleIfNeeded() {
        guard subject.value.hasTrack || subject.value.playback != .stopped else { return }
        subject.send(.idle(providerID: id))
    }

    func warnAboutPermissionOnce() {
        guard !hasWarnedAboutPermission else { return }
        hasWarnedAboutPermission = true
        Log.media.error("""
            Automation permission for \(self.configuration.displayName, privacy: .public) was refused. \
            Now Playing metadata still works; transport controls and the playhead do not. \
            Grant access in System Settings ▸ Privacy & Security ▸ Automation.
            """)
    }
}

extension ScriptablePlayerConfiguration {
    /// Music's `duration` property is in seconds; Spotify's is milliseconds.
    /// (Both report milliseconds in their *notifications*, hence two scales.)
    var scriptDurationScale: Double {
        switch id {
        case "spotify": return 1000
        default: return 1
        }
    }
}
