import AppKit
import Combine

/// Fans several `MediaProvider`s into the single Now Playing state the UI sees.
///
/// The manager owns no timers. Providers push snapshots on change; the playhead
/// is extrapolated from the last snapshot (`MediaSnapshot.position(at:)`), so an
/// idle Dyland does no work at all.
@MainActor
final class MediaManager: ObservableObject {

    /// State of whichever provider is currently authoritative.
    @Published private(set) var snapshot: MediaSnapshot?
    /// Artwork for `snapshot.track`, fetched lazily and cached per track id.
    @Published private(set) var artwork: NSImage?
    /// False when no provider is installed or all of them failed.
    @Published private(set) var isAvailable: Bool = false

    /// Raised when a *different* track starts. The app delegate forwards this
    /// to the state machine as `.mediaChanged`.
    var onTrackChanged: ((MediaTrack) -> Void)?

    private let providers: [MediaProvider]
    private var cancellables = Set<AnyCancellable>()
    private var latest: [String: MediaSnapshot] = [:]
    /// Provider id → the order in which it last reported playing. Used to pick
    /// the active provider when two apps both have media loaded.
    private var lastPlayingSequence: [String: Int] = [:]
    private var sequenceCounter = 0
    private var artworkTask: Task<Void, Never>?
    private var artworkTrackID: String?
    private var isStarted = false

    init(providers: [MediaProvider]) {
        self.providers = providers
    }

    deinit {
        artworkTask?.cancel()
    }

    var activeProvider: MediaProvider? {
        guard let id = snapshot?.providerID else { return nil }
        return providers.first { $0.id == id }
    }

    var track: MediaTrack? { snapshot?.track }
    var isPlaying: Bool { snapshot?.playback.isPlaying ?? false }

    // MARK: - Lifecycle

    func start() {
        guard !isStarted else { return }
        isStarted = true

        let installed = providers.filter(\.isInstalled)
        isAvailable = !installed.isEmpty

        guard isAvailable else {
            Log.media.notice("No media providers are installed; Now Playing will stay empty")
            return
        }

        for provider in installed {
            provider.snapshots
                .sink { [weak self] snapshot in
                    self?.ingest(snapshot)
                }
                .store(in: &cancellables)
            provider.start()
        }

        Task { [providers = installed] in
            for provider in providers {
                await provider.refresh()
            }
        }
    }

    func stop() {
        guard isStarted else { return }
        isStarted = false
        cancellables.removeAll()
        artworkTask?.cancel()
        artworkTask = nil
        for provider in providers { provider.stop() }
        latest.removeAll()
        lastPlayingSequence.removeAll()
        snapshot = nil
        artwork = nil
    }

    /// Re-pulls every provider. Called after wake, when push notifications may
    /// have been missed.
    func refreshAll() async {
        for provider in providers where provider.isInstalled {
            await provider.refresh()
        }
    }

    // MARK: - Transport

    func togglePlayPause() async { await activeProvider?.togglePlayPause() }
    func nextTrack() async { await activeProvider?.nextTrack() }
    func previousTrack() async { await activeProvider?.previousTrack() }

    // MARK: - Fan-in

    private func ingest(_ incoming: MediaSnapshot) {
        latest[incoming.providerID] = incoming

        if incoming.playback.isPlaying {
            sequenceCounter += 1
            lastPlayingSequence[incoming.providerID] = sequenceCounter
        }

        let previousTrackID = snapshot?.track?.id
        let selected = selectActive()

        guard selected != snapshot else { return }
        snapshot = selected

        if let track = selected?.track, track.id != previousTrackID {
            Log.media.info("Now playing: \(track.title, privacy: .public) [\(selected?.providerID ?? "?", privacy: .public)]")
            loadArtwork(for: track)
            onTrackChanged?(track)
        } else if selected?.track == nil {
            artworkTask?.cancel()
            artworkTrackID = nil
            artwork = nil
        }
    }

    /// Picks the authoritative snapshot.
    ///
    /// Precedence: something that is playing wins (most recently started, so
    /// hitting play in Spotify takes over from a paused Music); otherwise the
    /// most recently updated provider that still has a track loaded.
    private func selectActive() -> MediaSnapshot? {
        let playing = latest.values.filter { $0.playback.isPlaying }
        if !playing.isEmpty {
            return playing.max { lhs, rhs in
                (lastPlayingSequence[lhs.providerID] ?? 0) < (lastPlayingSequence[rhs.providerID] ?? 0)
            }
        }

        let loaded = latest.values.filter(\.hasTrack)
        if !loaded.isEmpty {
            return loaded.max { $0.capturedAt < $1.capturedAt }
        }

        return nil
    }

    private func loadArtwork(for track: MediaTrack) {
        guard artworkTrackID != track.id else { return }
        artworkTask?.cancel()
        artwork = nil
        artworkTrackID = track.id

        guard let provider = activeProvider else { return }
        artworkTask = Task { [weak self] in
            let image = await provider.artwork(for: track)
            guard !Task.isCancelled else { return }
            guard let self, self.artworkTrackID == track.id else { return }
            self.artwork = image
        }
    }
}
