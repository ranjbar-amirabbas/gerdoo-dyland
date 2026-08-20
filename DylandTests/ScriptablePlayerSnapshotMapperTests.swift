import XCTest
@testable import Dyland

/// The mapper is where Music and Spotify disagree with each other, so it gets
/// the closest scrutiny in the media stack.
final class ScriptablePlayerSnapshotMapperTests: XCTestCase {

    private let now = Date(timeIntervalSince1970: 5_000)

    // MARK: Notification payloads

    func testMusicNotificationConvertsMillisecondsToSeconds() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .appleMusic,
            userInfo: [
                "Player State": "Playing",
                "Name": "Nightfall",
                "Artist": "Kite Season",
                "Album": "Long Way Round",
                "Total Time": NSNumber(value: 214_000)
            ],
            now: now
        )

        XCTAssertEqual(snapshot.playback, .playing)
        XCTAssertEqual(snapshot.track?.title, "Nightfall")
        XCTAssertEqual(snapshot.track?.duration ?? 0, 214, accuracy: 0.001)
        XCTAssertNil(snapshot.position, "Music never reports the playhead in its notification")
    }

    func testSpotifyNotificationCarriesThePlayhead() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .spotify,
            userInfo: [
                "Player State": "Playing",
                "Name": "Nightfall",
                "Artist": "Kite Season",
                "Album": "Long Way Round",
                "Duration": NSNumber(value: 214_000),
                "Playback Position": NSNumber(value: 42.5),
                "Track ID": "spotify:track:abc"
            ],
            now: now
        )

        XCTAssertEqual(snapshot.position ?? 0, 42.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.track?.duration ?? 0, 214, accuracy: 0.001)
        XCTAssertEqual(snapshot.track?.id, "spotify:spotify:track:abc")
    }

    func testStoppedNotificationYieldsAnIdleSnapshot() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .appleMusic,
            userInfo: ["Player State": "Stopped", "Name": "Leftover"],
            now: now
        )

        XCTAssertNil(snapshot.track)
        XCTAssertEqual(snapshot.playback, .stopped)
    }

    func testMissingTitleYieldsAnIdleSnapshot() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .spotify,
            userInfo: ["Player State": "Playing"],
            now: now
        )

        XCTAssertNil(snapshot.track)
    }

    func testEmptyMetadataFieldsBecomeNilNotEmptyStrings() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .spotify,
            userInfo: ["Player State": "Paused", "Name": "Untitled", "Artist": "", "Album": ""],
            now: now
        )

        XCTAssertNil(snapshot.track?.artist)
        XCTAssertNil(snapshot.track?.album)
        XCTAssertNil(snapshot.track?.subtitle)
    }

    func testUnknownStateStringIsTreatedAsStopped() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .appleMusic,
            userInfo: ["Player State": "Buffering", "Name": "X"],
            now: now
        )

        XCTAssertEqual(snapshot.playback, .stopped)
    }

    // MARK: Script results

    private func scriptResult(_ fields: [String]) -> String {
        fields.joined(separator: Scripts.separator)
    }

    func testMusicScriptDurationIsAlreadyInSeconds() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .appleMusic,
            scriptResult: scriptResult(["playing", "Nightfall", "Kite Season", "Long Way Round", "214.0", "42.5"]),
            now: now
        )

        XCTAssertEqual(snapshot.track?.duration ?? 0, 214, accuracy: 0.001)
        XCTAssertEqual(snapshot.position ?? 0, 42.5, accuracy: 0.001)
        XCTAssertEqual(snapshot.playback, .playing)
    }

    func testSpotifyScriptDurationIsInMilliseconds() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .spotify,
            scriptResult: scriptResult(["paused", "Nightfall", "Kite Season", "Long Way Round", "214000", "42.5"]),
            now: now
        )

        XCTAssertEqual(snapshot.track?.duration ?? 0, 214, accuracy: 0.001)
        XCTAssertEqual(snapshot.playback, .paused)
    }

    func testBareStoppedScriptResult() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .appleMusic,
            scriptResult: "stopped",
            now: now
        )

        XCTAssertNil(snapshot.track)
        XCTAssertEqual(snapshot.playback, .stopped)
    }

    func testTruncatedScriptResultDoesNotProduceAHalfTrack() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .appleMusic,
            scriptResult: scriptResult(["playing", "Nightfall"]),
            now: now
        )

        XCTAssertNil(snapshot.track, "A partial tuple must not become a track with missing fields")
    }

    func testUnparseableDurationLeavesTheTrackWithoutOne() {
        let snapshot = ScriptablePlayerSnapshotMapper.snapshot(
            configuration: .appleMusic,
            scriptResult: scriptResult(["playing", "Nightfall", "A", "B", "missing value", "0"]),
            now: now
        )

        XCTAssertNotNil(snapshot.track)
        XCTAssertNil(snapshot.track?.duration)
        XCTAssertNil(snapshot.progress(at: now), "No duration means no progress bar, not a divide by zero")
    }
}

final class NotchScreenSelectorTests: XCTestCase {

    private let notched = ScreenDescriptor(
        frame: CGRect(x: 0, y: 0, width: 1710, height: 1107),
        safeAreaTopInset: 33,
        auxiliaryTopLeftWidth: 763,
        auxiliaryTopRightWidth: 762,
        isBuiltIn: true
    )

    private let external = ScreenDescriptor(
        frame: CGRect(x: 0, y: 0, width: 2560, height: 1440),
        safeAreaTopInset: 0,
        auxiliaryTopLeftWidth: 0,
        auxiliaryTopRightWidth: 0,
        isBuiltIn: false
    )

    func testNotchedDisplayWinsEvenWhenItIsNotPrimary() {
        XCTAssertEqual(NotchScreenSelector.selectIndex(from: [external, notched]), 1)
    }

    func testFallsBackToThePrimaryDisplay() {
        XCTAssertEqual(NotchScreenSelector.selectIndex(from: [external, external]), 0)
    }

    func testNoDisplaysMeansNoSelection() {
        XCTAssertNil(NotchScreenSelector.selectIndex(from: []))
    }

    func testSingleNotchedDisplay() {
        XCTAssertEqual(NotchScreenSelector.selectIndex(from: [notched]), 0)
    }
}
