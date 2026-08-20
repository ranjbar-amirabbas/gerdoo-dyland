import XCTest
@testable import Dyland

@MainActor
final class DragDropManagerTests: XCTestCase {

    private var directory: URL!
    private var defaults: UserDefaults!
    private var settings: SettingsManager!
    private var shelf: FileShelfManager!
    private var machine: NotchStateMachine!
    private var manager: DragDropManager!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DylandDropTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let suite = "DylandDropTests-\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        settings = SettingsManager(store: SettingsStore(defaults: defaults))
        shelf = FileShelfManager()
        machine = NotchStateMachine(config: settings.notchConfig)
        manager = DragDropManager(shelf: shelf, stateMachine: machine, settings: settings)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        defaults.removePersistentDomain(forName: defaults.description)
        try super.tearDownWithError()
    }

    private func makeFile(_ name: String) throws -> URL {
        let url = directory.appendingPathComponent(name)
        try "x".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testAcceptedDropShelvesFiles() throws {
        XCTAssertTrue(manager.handleDrop([try makeFile("a.txt")]))
        XCTAssertEqual(shelf.count, 1)
    }

    func testDropIsDeclinedWhenTheModuleIsDisabled() throws {
        settings.fileShelfEnabled = false

        XCTAssertFalse(manager.acceptsDrops)
        XCTAssertFalse(manager.handleDrop([try makeFile("a.txt")]))
        XCTAssertTrue(shelf.isEmpty)
    }

    func testDuplicateOnlyDropStillShowsTheShelf() throws {
        let url = try makeFile("a.txt")
        XCTAssertTrue(manager.handleDrop([url]))

        XCTAssertFalse(manager.handleDrop([url]), "Nothing new was added, so AppKit should snap back")
        XCTAssertEqual(machine.state, .expanded(.fileShelf), "The user still aimed at the shelf")
        XCTAssertEqual(shelf.count, 1)
    }

    func testUnreadableDropIsDeclined() {
        XCTAssertFalse(manager.handleDrop([directory.appendingPathComponent("ghost.txt")]))
        XCTAssertTrue(shelf.isEmpty)
    }
}
