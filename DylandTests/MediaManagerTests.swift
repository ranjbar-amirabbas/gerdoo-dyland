import XCTest
@testable import Dyland

@MainActor
final class MediaManagerTests: XCTestCase {

    private func makeManager(_ providers: [MockMediaProvider]) -> MediaManager {
        let manager = MediaManager(providers: providers)
        manager.start()
        return manager
    }

    func testStartsOnlyInstalledProviders() {
        let installed = MockMediaProvider(id: "a")
        let missing = MockMediaProvider(id: "b", isInstalled: false)
        let manager = makeManager([installed, missing])

        XCTAssertTrue(manager.isAvailable)
        XCTAssertEqual(installed.startCount, 1)
        XCTAssertEqual(missing.startCount, 0)
    }

    func testUnavailableWhenNothingIsInstalled() {
        let manager = makeManager([MockMediaProvider(id: "a", isInstalled: false)])

        XCTAssertFalse(manager.isAvailable)
        XCTAssertNil(manager.snapshot)
        XCTAssertNil(manager.track)
    }

    func testStartIsIdempotent() {
        let provider = MockMediaProvider()
        let manager = makeManager([provider])
        manager.start()

        XCTAssertEqual(provider.startCount, 1)
    }

    func testPublishesTheOnlyProvidersState() {
        let provider = MockMediaProvider()
        let manager = makeManager([provider])
        let track = MockMediaProvider.sampleTrack()

        provider.emit(track: track, playback: .playing, position: 10)

        XCTAssertEqual(manager.track, track)
        XCTAssertTrue(manager.isPlaying)
    }

    func testPlayingProviderOutranksPausedOne() {
        let music = MockMediaProvider(id: "music")
        let spotify = MockMediaProvider(id: "spotify")
        let manager = makeManager([music, spotify])

        music.emit(track: MockMediaProvider.sampleTrack(title: "Paused One"), playback: .paused, position: 0)
        spotify.emit(track: MockMediaProvider.sampleTrack(title: "Playing One"), playback: .playing, position: 0)

        XCTAssertEqual(manager.snapshot?.providerID, "spotify")
        XCTAssertEqual(manager.track?.title, "Playing One")
    }

    func testMostRecentlyStartedPlayerWins() {
        let music = MockMediaProvider(id: "music")
        let spotify = MockMediaProvider(id: "spotify")
        let manager = makeManager([music, spotify])

        music.emit(track: MockMediaProvider.sampleTrack(title: "First"), playback: .playing)
        spotify.emit(track: MockMediaProvider.sampleTrack(title: "Second"), playback: .playing)

        XCTAssertEqual(manager.snapshot?.providerID, "spotify")
    }

    func testFallsBackToALoadedTrackWhenNothingIsPlaying() {
        let music = MockMediaProvider(id: "music")
        let manager = makeManager([music])

        music.emit(track: MockMediaProvider.sampleTrack(), playback: .paused, position: 30)

        XCTAssertEqual(manager.snapshot?.providerID, "music")
        XCTAssertFalse(manager.isPlaying)
    }

    func testTrackChangeCallbackFiresOncePerTrack() {
        let provider = MockMediaProvider()
        let manager = makeManager([provider])
        var changes: [String] = []
        manager.onTrackChanged = { changes.append($0.title) }

        let track = MockMediaProvider.sampleTrack(title: "One")
        provider.emit(track: track, playback: .playing, position: 0)
        provider.emit(track: track, playback: .playing, position: 5)
        provider.emit(track: MockMediaProvider.sampleTrack(title: "Two"), playback: .playing, position: 0)

        XCTAssertEqual(changes, ["One", "Two"], "A position tick is not a track change")
    }

    func testStoppingClearsStateAndProviders() {
        let provider = MockMediaProvider()
        let manager = makeManager([provider])
        provider.emit(track: MockMediaProvider.sampleTrack(), playback: .playing)

        manager.stop()

        XCTAssertNil(manager.snapshot)
        XCTAssertEqual(provider.stopCount, 1)
    }

    func testTransportCommandsGoToTheActiveProvider() async {
        let music = MockMediaProvider(id: "music")
        let spotify = MockMediaProvider(id: "spotify")
        let manager = makeManager([music, spotify])
        spotify.emit(track: MockMediaProvider.sampleTrack(), playback: .playing)

        await manager.nextTrack()
        await manager.previousTrack()

        XCTAssertEqual(spotify.commands, ["next", "previous"])
        XCTAssertTrue(music.commands.isEmpty)
    }
}

final class MediaSnapshotTests: XCTestCase {

    private let start = Date(timeIntervalSince1970: 1_000)

    func testPositionExtrapolatesWhilePlaying() {
        let snapshot = MediaSnapshot(
            providerID: "m",
            track: MediaTrack(title: "T", duration: 100),
            playback: .playing,
            position: 10,
            capturedAt: start
        )

        XCTAssertEqual(snapshot.position(at: start.addingTimeInterval(5)) ?? 0, 15, accuracy: 0.001)
    }

    func testPositionIsFrozenWhilePaused() {
        let snapshot = MediaSnapshot(
            providerID: "m",
            track: MediaTrack(title: "T", duration: 100),
            playback: .paused,
            position: 10,
            capturedAt: start
        )

        XCTAssertEqual(snapshot.position(at: start.addingTimeInterval(30)) ?? 0, 10, accuracy: 0.001)
    }

    func testPositionIsClampedToTheTrackDuration() {
        let snapshot = MediaSnapshot(
            providerID: "m",
            track: MediaTrack(title: "T", duration: 20),
            playback: .playing,
            position: 10,
            capturedAt: start
        )

        XCTAssertEqual(snapshot.position(at: start.addingTimeInterval(600)) ?? 0, 20, accuracy: 0.001)
        XCTAssertEqual(snapshot.progress(at: start.addingTimeInterval(600)) ?? 0, 1, accuracy: 0.001)
    }

    func testProgressIsNilWithoutADuration() {
        let snapshot = MediaSnapshot(
            providerID: "m",
            track: MediaTrack(title: "T"),
            playback: .playing,
            position: 10,
            capturedAt: start
        )

        XCTAssertNil(snapshot.progress(at: start))
    }

    func testTrackIdentityIgnoresPositionButNotMetadata() {
        let a = MediaTrack(title: "T", artist: "A", album: "B")
        let b = MediaTrack(title: "T", artist: "A", album: "B")
        let c = MediaTrack(title: "T", artist: "A", album: "C")

        XCTAssertEqual(a.id, b.id)
        XCTAssertNotEqual(a.id, c.id)
    }
}
