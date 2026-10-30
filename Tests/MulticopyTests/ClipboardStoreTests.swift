import XCTest
@testable import MulticopyCore

final class ClipboardStoreTests: XCTestCase {
    private var directory: URL!
    private var fileURL: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MulticopyTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("history.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    func testNewestCopiesComeFirst() {
        let store = ClipboardStore(fileURL: fileURL)
        store.ingest("first", at: Date(timeIntervalSince1970: 100))
        store.ingest("second", at: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(store.visibleItems().map(\.text), ["second", "first"])
    }

    func testCopyingSameTextMovesItToTopWithoutDuplicating() {
        let store = ClipboardStore(fileURL: fileURL)
        store.ingest("hello", at: Date(timeIntervalSince1970: 100))
        store.ingest("world", at: Date(timeIntervalSince1970: 200))
        store.ingest("hello", at: Date(timeIntervalSince1970: 300))

        XCTAssertEqual(store.visibleItems().map(\.text), ["hello", "world"])
        XCTAssertEqual(store.visibleItems().first?.createdAt, Date(timeIntervalSince1970: 300))
    }

    func testPinnedItemsSortFirstAndSurviveCleanup() {
        let store = ClipboardStore(fileURL: fileURL, maxUnpinnedItems: 2)
        store.ingest("keep me", at: Date(timeIntervalSince1970: 100))
        let pinnedID = store.visibleItems()[0].id
        store.togglePin(pinnedID)

        store.ingest("two", at: Date(timeIntervalSince1970: 200))
        store.ingest("three", at: Date(timeIntervalSince1970: 300))
        store.ingest("four", at: Date(timeIntervalSince1970: 400))

        XCTAssertEqual(store.visibleItems().map(\.text), ["keep me", "four", "three"])
    }

    func testSearchIsCaseInsensitiveAndTrimsWhitespace() {
        let store = ClipboardStore(fileURL: fileURL)
        store.ingest("Hello World", at: Date(timeIntervalSince1970: 100))
        store.ingest("Goodbye", at: Date(timeIntervalSince1970: 200))

        XCTAssertEqual(store.visibleItems(query: "  hello  ").map(\.text), ["Hello World"])
    }

    func testHistoryPersistsAcrossInstances() {
        let store = ClipboardStore(fileURL: fileURL)
        store.ingest("persisted", at: Date(timeIntervalSince1970: 100))
        store.saveNow()

        let reloaded = ClipboardStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.visibleItems().map(\.text), ["persisted"])
    }

    func testDeleteAndClearUnpinned() {
        let store = ClipboardStore(fileURL: fileURL)
        store.ingest("one", at: Date(timeIntervalSince1970: 100))
        store.ingest("two", at: Date(timeIntervalSince1970: 200))
        store.ingest("three", at: Date(timeIntervalSince1970: 300))

        let pinnedID = store.visibleItems()[0].id
        store.togglePin(pinnedID)

        let twoID = store.visibleItems().first(where: { $0.text == "two" })!.id
        store.delete(twoID)
        XCTAssertFalse(store.visibleItems().contains(where: { $0.id == twoID }))

        store.clearUnpinned()
        XCTAssertEqual(store.visibleItems().map(\.text), ["three"])
    }

    func testBlankTextIsIgnored() {
        let store = ClipboardStore(fileURL: fileURL)
        store.ingest("   \n\t ")
        XCTAssertTrue(store.items.isEmpty)
    }
}
