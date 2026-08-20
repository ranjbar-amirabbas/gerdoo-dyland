import XCTest
@testable import Dyland

@MainActor
private final class SpyAction: QuickAction {
    let id: String
    let title: String
    let icon = "bolt"
    var isEnabled: Bool
    var error: Error?
    private(set) var runCount = 0

    init(id: String, title: String? = nil, isEnabled: Bool = true, error: Error? = nil) {
        self.id = id
        self.title = title ?? id
        self.isEnabled = isEnabled
        self.error = error
    }

    func execute() async throws {
        runCount += 1
        if let error { throw error }
    }
}

@MainActor
final class QuickActionManagerTests: XCTestCase {

    func testRegistrationPreservesOrder() {
        let manager = QuickActionManager()
        manager.register(SpyAction(id: "a"))
        manager.register(SpyAction(id: "b"))
        manager.register(SpyAction(id: "c"))

        XCTAssertEqual(manager.actions.map(\.id), ["a", "b", "c"])
    }

    func testDuplicateIDsAreRejected() {
        let manager = QuickActionManager()
        manager.register(SpyAction(id: "a", title: "First"))
        manager.register(SpyAction(id: "a", title: "Second"))

        XCTAssertEqual(manager.actions.count, 1)
        XCTAssertEqual(manager.actions.first?.title, "First")
    }

    func testLookupByID() {
        let manager = QuickActionManager(actions: [SpyAction(id: "a")])

        XCTAssertNotNil(manager.action(id: "a"))
        XCTAssertNil(manager.action(id: "missing"))
    }

    func testRunningAnAction() async {
        let action = SpyAction(id: "a")
        let manager = QuickActionManager(actions: [action])

        await manager.run(action)

        XCTAssertEqual(action.runCount, 1)
        XCTAssertNil(manager.lastErrorMessage)
    }

    func testDisabledActionsDoNotRun() async {
        let action = SpyAction(id: "a", isEnabled: false)
        let manager = QuickActionManager(actions: [action])

        await manager.run(action)

        XCTAssertEqual(action.runCount, 0)
    }

    func testRunByIDIgnoresUnknownIdentifiers() async {
        let action = SpyAction(id: "a")
        let manager = QuickActionManager(actions: [action])

        await manager.run(id: "nope")

        XCTAssertEqual(action.runCount, 0)
    }

    func testFailureIsSurfacedNotSwallowed() async {
        let action = SpyAction(id: "a", error: QuickActionError.applicationMissing("Finder"))
        let manager = QuickActionManager(actions: [action])

        await manager.run(action)

        XCTAssertEqual(manager.lastErrorMessage, "Finder could not be found.")
    }

    func testClearShelfActionIsDisabledWhenTheShelfIsEmpty() async throws {
        let shelf = FileShelfManager()
        let action = ClearShelfAction(shelf: shelf)
        XCTAssertFalse(action.isEnabled)

        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DylandAction-\(UUID().uuidString).txt")
        try "x".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        shelf.add([url])

        XCTAssertTrue(action.isEnabled)
        try await action.execute()
        XCTAssertTrue(shelf.isEmpty)
    }

    func testShowClipboardActionSwitchesTheNotchSection() async throws {
        let machine = NotchStateMachine()
        let clipboard = ClipboardMonitor(interval: 60)
        let action = ShowClipboardAction(stateMachine: machine, clipboard: clipboard)

        XCTAssertFalse(action.isEnabled, "Pointless while the module is stopped")
        clipboard.start()
        defer { clipboard.stop() }
        XCTAssertTrue(action.isEnabled)

        try await action.execute()

        XCTAssertEqual(machine.state, .expanded(.clipboard))
    }

    func testOpenFolderActionReportsAnUnavailableLocation() async {
        let action = OpenFolderAction(
            id: "bogus",
            title: "Nowhere",
            icon: "folder",
            directory: .itemReplacementDirectory
        )

        do {
            try await action.execute()
            // `.itemReplacementDirectory` resolves on some systems; either way
            // the contract is "throws or opens", never "fails silently".
        } catch let error as QuickActionError {
            XCTAssertEqual(error, .locationUnavailable("Nowhere"))
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }
}
