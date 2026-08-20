import AppKit
import XCTest
@testable import Dyland

@MainActor
final class ClipboardMonitorTests: XCTestCase {

    private var pasteboard: NSPasteboard!
    private var monitor: ClipboardMonitor!

    override func setUp() {
        super.setUp()
        // A private pasteboard keeps the tests away from the user's clipboard.
        pasteboard = NSPasteboard(name: NSPasteboard.Name("DylandTests-\(UUID().uuidString)"))
        monitor = ClipboardMonitor(pasteboard: pasteboard, capacity: 3, interval: 60)
    }

    override func tearDown() {
        monitor.stop()
        pasteboard.releaseGlobally()
        super.tearDown()
    }

    private func copyText(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func testCapturesCopiedText() {
        monitor.start()
        copyText("hello")

        monitor.poll()

        XCTAssertEqual(monitor.entries.count, 1)
        XCTAssertEqual(monitor.entries.first?.payload, .text("hello"))
    }

    func testStartIgnoresWhateverWasAlreadyOnTheClipboard() {
        copyText("pre-existing")
        monitor.start()

        monitor.poll()

        XCTAssertTrue(monitor.entries.isEmpty)
    }

    func testNewestEntryComesFirstAndCapacityIsEnforced() {
        monitor.start()
        for text in ["one", "two", "three", "four"] {
            copyText(text)
            monitor.poll()
        }

        XCTAssertEqual(monitor.entries.count, 3)
        XCTAssertEqual(monitor.entries.map(\.preview), ["four", "three", "two"])
    }

    func testRepeatedIdenticalCopyIsNotDuplicated() {
        monitor.start()
        copyText("same")
        monitor.poll()
        copyText("same")
        monitor.poll()

        XCTAssertEqual(monitor.entries.count, 1)
    }

    func testCopyBackDoesNotRecordItself() {
        monitor.start()
        copyText("original")
        monitor.poll()
        let entry = monitor.entries[0]

        monitor.copyBack(entry)
        monitor.poll()

        XCTAssertEqual(monitor.entries.count, 1, "Restoring an entry must not push a duplicate")
        XCTAssertEqual(pasteboard.string(forType: .string), "original")
    }

    func testCaptureCallbackFires() {
        var captured: [String] = []
        monitor.onCapture = { captured.append($0.preview) }
        monitor.start()

        copyText("ping")
        monitor.poll()

        XCTAssertEqual(captured, ["ping"])
    }

    func testUnsupportedContentIsSkippedButAcknowledged() {
        monitor.start()
        pasteboard.clearContents()
        pasteboard.setData(Data([0x00, 0x01]), forType: .tiff)

        monitor.poll()
        monitor.poll()

        XCTAssertTrue(monitor.entries.isEmpty)
    }

    func testStopReleasesTheTimer() {
        monitor.start()
        XCTAssertTrue(monitor.isRunning)

        monitor.stop()

        XCTAssertFalse(monitor.isRunning)
    }

    func testPreviewCollapsesWhitespace() {
        let entry = ClipboardEntry(payload: .text("  hello\n\n  world \t"))
        XCTAssertEqual(entry.preview, "hello world")
    }

    func testFilePreviewSummarisesMultipleURLs() {
        let entry = ClipboardEntry(payload: .files([
            URL(fileURLWithPath: "/tmp/a.txt"),
            URL(fileURLWithPath: "/tmp/b.txt")
        ]))
        XCTAssertEqual(entry.preview, "a.txt +1")
    }
}
