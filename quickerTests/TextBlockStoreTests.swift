import SwiftData
import XCTest
@testable import quicker

@MainActor
final class TextBlockStoreTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TextBlockEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testCreateFetchUpdateDelete() throws {
        let container = try makeInMemoryContainer()
        let store = TextBlockStore(modelContainer: container)

        let created = try store.create(title: "问候", content: "你好，世界")
        var all = try store.fetchAllBySortOrder()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.uuid, created.uuid)
        XCTAssertEqual(all.first?.sortOrder, 0)

        try store.update(id: created.uuid, title: "问候语", content: "你好，Quicker")
        all = try store.fetchAllBySortOrder()
        XCTAssertEqual(all.first?.title, "问候语")
        XCTAssertEqual(all.first?.content, "你好，Quicker")

        try store.delete(id: created.uuid)
        XCTAssertEqual(try store.fetchAllBySortOrder().count, 0)
    }

    func testMoveRewritesSortOrderContinuously() throws {
        let container = try makeInMemoryContainer()
        let store = TextBlockStore(modelContainer: container)
        _ = try store.create(title: "A", content: "A")
        _ = try store.create(title: "B", content: "B")
        _ = try store.create(title: "C", content: "C")
        _ = try store.create(title: "D", content: "D")

        try store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        let all = try store.fetchAllBySortOrder()
        XCTAssertEqual(all.map(\.title), ["B", "C", "A", "D"])
        XCTAssertEqual(all.map(\.sortOrder), [0, 1, 2, 3])
    }

    func testCreateRejectsEmptyContent() throws {
        let container = try makeInMemoryContainer()
        let store = TextBlockStore(modelContainer: container)

        XCTAssertThrowsError(try store.create(title: "X", content: "   ")) { error in
            XCTAssertEqual(error as? TextBlockStoreError, .emptyContent)
        }
    }
}
