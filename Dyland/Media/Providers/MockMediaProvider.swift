import AppKit
import Combine

/// Scripted provider used by the tests and by `DYLAND_DEBUG_MEDIA` runs.
///
/// It exists so the entire Now Playing UI and the media-driven notch
/// transitions can be exercised with no player installed and no Automation
/// permission prompt.
@MainActor
final class MockMediaProvider: MediaProvider {

    let id: String
    let displayName: String
    var isInstalled: Bool

    private let subject: CurrentValueSubject<MediaSnapshot, Never>
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var refreshCount = 0
    private(set) var commands: [String] = []
    var stubbedArtwork: NSImage?

    init(id: String = "mock", displayName: String = "Mock Player", isInstalled: Bool = true) {
        self.id = id
        self.displayName = displayName
        self.isInstalled = isInstalled
        self.subject = CurrentValueSubject(.idle(providerID: id))
    }

    var snapshots: AnyPublisher<MediaSnapshot, Never> { subject.eraseToAnyPublisher() }
    var currentSnapshot: MediaSnapshot { subject.value }

    func start() { startCount += 1 }
    func stop() { stopCount += 1 }
    func refresh() async { refreshCount += 1 }

    func play() async {
        commands.append("play")
        emit(playback: .playing)
    }

    func pause() async {
        commands.append("pause")
        emit(playback: .paused)
    }

    func togglePlayPause() async {
        commands.append("toggle")
        emit(playback: currentSnapshot.playback.isPlaying ? .paused : .playing)
    }

    func nextTrack() async { commands.append("next") }
    func previousTrack() async { commands.append("previous") }

    func artwork(for track: MediaTrack) async -> NSImage? { stubbedArtwork }

    // MARK: - Test scripting

    /// Pushes an arbitrary snapshot, as a real provider would on a push event.
    func emit(_ snapshot: MediaSnapshot) {
        subject.send(snapshot)
    }

    func emit(
        track: MediaTrack?,
        playback: MediaPlaybackState,
        position: TimeInterval? = nil,
        at date: Date = Date()
    ) {
        subject.send(MediaSnapshot(
            providerID: id,
            track: track,
            playback: playback,
            position: position,
            capturedAt: date
        ))
    }

    private func emit(playback: MediaPlaybackState) {
        var next = currentSnapshot
        next.playback = playback
        next.capturedAt = Date()
        subject.send(next)
    }

    static func sampleTrack(
        title: String = "Nightfall",
        artist: String = "Kite Season",
        album: String = "Long Way Round",
        duration: TimeInterval = 214
    ) -> MediaTrack {
        MediaTrack(title: title, artist: artist, album: album, duration: duration)
    }
}
