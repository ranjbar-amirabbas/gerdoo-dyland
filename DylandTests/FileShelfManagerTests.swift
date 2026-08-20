import XCTest
@testable import Dyland

@MainActor
final class FileShelfManagerTests: XCTestCase {

    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("DylandShelfTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        directory = nil
        try super.tearDownWithError()
    }

    @discardableResult
    private func makeFile(_ name: String, contents: String = "x") throws -> URL {
        let url = directory.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Adding

    func testAddShelvesReadableFiles() throws {
        let shelf = FileShelfManager()
        let a = try makeFile("a.txt")
        let b = try makeFile("b.txt")

        let added = shelf.add([a, b])

        XCTAssertEqual(added.count, 2)
        XCTAssertEqual(shelf.count, 2)
        XCTAssertEqual(Set(shelf.urls), Set([a, b].map { $0.resolvingSymlinksInPath().standardizedFileURL }))
    }

    func testNewestItemsComeFirst() throws {
        let shelf = FileShelfManager()
        let first = try makeFile("first.txt")
        let second = try makeFile("second.txt")

        shelf.add([first])
        shelf.add([second])

        XCTAssertEqual(shelf.items.first?.displayName, "second.txt")
    }

    func testDuplicatesAreRejected() throws {
        let shelf = FileShelfManager()
        let url = try makeFile("dupe.txt")

        XCTAssertEqual(shelf.add([url]).count, 1)
        XCTAssertEqual(shelf.add([url]).count, 0, "The same file must not shelve twice")
        XCTAssertEqual(shelf.count, 1)
    }

    func testDuplicatesAreDetectedThroughSymlinks() throws {
        let shelf = FileShelfManager()
        let real = try makeFile("real.txt")
        let link = directory.appendingPathComponent("link.txt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: real)

        shelf.add([real])
        XCTAssertEqual(shelf.add([link]).count, 0, "A symlink to a shelved file is the same file")
    }

    func testMissingFilesAreRefused() {
        let shelf = FileShelfManager()
        let ghost = directory.appendingPathComponent("nope.txt")

        XCTAssertEqual(shelf.add([ghost]).count, 0)
        XCTAssertTrue(shelf.isEmpty)
    }

    func testPartiallyValidDropShelvesWhatItCan() throws {
        let shelf = FileShelfManager()
        let good = try makeFile("good.txt")
        let ghost = directory.appendingPathComponent("ghost.txt")

        let added = shelf.add([ghost, good])

        XCTAssertEqual(added.count, 1)
        XCTAssertEqual(added.first?.displayName, "good.txt")
    }

    func testDirectoriesAreShelvable() throws {
        let shelf = FileShelfManager()
        let folder = directory.appendingPathComponent("Docs")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        let added = shelf.add([folder])

        XCTAssertEqual(added.count, 1)
        XCTAssertTrue(added[0].isDirectory)
        XCTAssertEqual(added[0].typeDescription, "Folder")
    }

    // MARK: Capacity

    func testCapacityDropsTheOldestItems() throws {
        let shelf = FileShelfManager(capacity: 3)
        for index in 0..<5 {
            shelf.add([try makeFile("file\(index).txt")])
        }

        XCTAssertEqual(shelf.count, 3)
        XCTAssertEqual(shelf.items.map(\.displayName), ["file4.txt", "file3.txt", "file2.txt"])
    }

    // MARK: Removal

    func testRemoveByID() throws {
        let shelf = FileShelfManager()
        shelf.add([try makeFile("a.txt"), try makeFile("b.txt")])
        let target = try XCTUnwrap(shelf.items.first)

        shelf.remove(id: target.id)

        XCTAssertEqual(shelf.count, 1)
        XCTAssertFalse(shelf.items.contains { $0.id == target.id })
    }

    func testRemoveBySetOfIDs() throws {
        let shelf = FileShelfManager()
        shelf.add([try makeFile("a.txt"), try makeFile("b.txt"), try makeFile("c.txt")])
        let doomed = Set(shelf.items.prefix(2).map(\.id))

        shelf.remove(ids: doomed)

        XCTAssertEqual(shelf.count, 1)
    }

    func testClearEmptiesTheShelf() throws {
        let shelf = FileShelfManager()
        shelf.add([try makeFile("a.txt")])

        shelf.clear()

        XCTAssertTrue(shelf.isEmpty)
    }

    // MARK: Staleness

    func testDeletedFileBecomesInaccessibleThenPrunes() throws {
        let shelf = FileShelfManager()
        let url = try makeFile("doomed.txt")
        shelf.add([url])
        XCTAssertTrue(try XCTUnwrap(shelf.items.first).isAccessible)

        try FileManager.default.removeItem(at: url)

        XCTAssertFalse(try XCTUnwrap(shelf.items.first).isAccessible,
                       "The shelf must report staleness rather than pretend the file exists")
        XCTAssertEqual(shelf.pruneUnreachable(), 1)
        XCTAssertTrue(shelf.isEmpty)
    }

    func testShelvingNeverTouchesTheOriginal() throws {
        let shelf = FileShelfManager()
        let url = try makeFile("keep.txt", contents: "original")

        shelf.add([url])
        shelf.clear()

        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "original")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: Expiration

    func testExpirationRemovesOldItemsOnly() throws {
        let shelf = FileShelfManager()
        shelf.expiration = 60

        let now = Date()
        shelf.add([try makeFile("old.txt")], now: now.addingTimeInterval(-120))
        shelf.add([try makeFile("fresh.txt")], now: now)

        XCTAssertEqual(shelf.pruneExpired(now: now), 1)
        XCTAssertEqual(shelf.items.map(\.displayName), ["fresh.txt"])
    }

    func testExpirationIsOffByDefault() throws {
        let shelf = FileShelfManager()
        shelf.add([try makeFile("old.txt")], now: Date(timeIntervalSince1970: 0))

        XCTAssertEqual(shelf.pruneExpired(now: Date()), 0)
        XCTAssertEqual(shelf.count, 1)
    }
}
