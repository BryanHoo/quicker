import SwiftData
import XCTest
@testable import quicker

@MainActor
final class ClipboardStoreTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testInsertAndFetchLatest() throws {
        let container = try makeInMemoryContainer()
        let store = ClipboardStore(
            modelContainer: container,
            preferences: PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        )

        _ = try store.insert(text: "A")
        _ = try store.insert(text: "B")

        let latest = try store.fetchLatest(limit: 10)
        XCTAssertEqual(latest.map(\.text), ["B", "A"])
    }

    func testInsertSetsKindAndContentHashForText() throws {
        let container = try makeInMemoryContainer()
        let store = ClipboardStore(
            modelContainer: container,
            preferences: PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        )

        _ = try store.insert(text: "A")

        let entry = try XCTUnwrap(store.fetchLatest(limit: 1).first)
        XCTAssertEqual(entry.kindRaw, "text")
        XCTAssertNotNil(entry.contentHash)
    }

    func testDedupeAdjacentEnabled() throws {
        let container = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = PreferencesStore(userDefaults: defaults)
        prefs.dedupeAdjacentEnabled = true
        prefs.maxHistoryCount = 200

        let store = ClipboardStore(modelContainer: container, preferences: prefs)

        XCTAssertEqual(try store.insert(text: "A"), true)
        XCTAssertEqual(try store.insert(text: "A"), false)
        XCTAssertEqual(try store.fetchLatest(limit: 10).map(\.text), ["A"])
    }

    func testMaxHistoryCountTrims() throws {
        let container = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = PreferencesStore(userDefaults: defaults)
        prefs.maxHistoryCount = 2
        prefs.dedupeAdjacentEnabled = false

        let store = ClipboardStore(modelContainer: container, preferences: prefs)

        _ = try store.insert(text: "A")
        _ = try store.insert(text: "B")
        _ = try store.insert(text: "C")

        let latest = try store.fetchLatest(limit: 10).map(\.text)
        XCTAssertEqual(latest, ["C", "B"])
    }

    func testClear() throws {
        let container = try makeInMemoryContainer()
        let store = ClipboardStore(
            modelContainer: container,
            preferences: PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        )

        _ = try store.insert(text: "A")
        try store.clear()
        XCTAssertEqual(try store.fetchLatest(limit: 10).count, 0)
    }
}
