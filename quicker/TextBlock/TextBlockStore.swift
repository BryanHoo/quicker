import Foundation
import SwiftData

enum TextBlockStoreError: Error, Equatable {
    case emptyContent
    case notFound
}

@MainActor
final class TextBlockStore {
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchAllBySortOrder() throws -> [TextBlockEntry] {
        let descriptor = FetchDescriptor<TextBlockEntry>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward),
            ]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(title: String, content: String, now: Date = .now) throws -> TextBlockEntry {
        let normalizedContent = try normalizedContent(content)
        let normalizedTitle = normalizedTitle(title, content: normalizedContent)
        let nextOrder = try (fetchAllBySortOrder().last?.sortOrder ?? -1) + 1

        let entry = TextBlockEntry(
            title: normalizedTitle,
            content: normalizedContent,
            sortOrder: nextOrder,
            createdAt: now,
            updatedAt: now
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    func update(id: UUID, title: String, content: String, now: Date = .now) throws {
        let entry = try find(id: id)
        let normalizedContent = try normalizedContent(content)
        entry.title = normalizedTitle(title, content: normalizedContent)
        entry.content = normalizedContent
        entry.updatedAt = now
        try context.save()
    }

    func delete(id: UUID) throws {
        let entry = try find(id: id)
        context.delete(entry)

        let all = try fetchAllBySortOrder()
        for (index, item) in all.enumerated() {
            item.sortOrder = index
        }
        try context.save()
    }

    func move(fromOffsets: IndexSet, toOffset: Int, now: Date = .now) throws {
        guard fromOffsets.isEmpty == false else { return }

        let ordered = try fetchAllBySortOrder()
        let sources = fromOffsets.sorted()

        var moving: [TextBlockEntry] = []
        var remaining: [TextBlockEntry] = []
        for (index, entry) in ordered.enumerated() {
            if fromOffsets.contains(index) {
                moving.append(entry)
            } else {
                remaining.append(entry)
            }
        }

        var destination = toOffset
        for source in sources where source < toOffset {
            destination -= 1
        }
        destination = min(max(0, destination), remaining.count)

        remaining.insert(contentsOf: moving, at: destination)
        for (index, entry) in remaining.enumerated() {
            entry.sortOrder = index
            entry.updatedAt = now
        }
        try context.save()
    }

    private func find(id: UUID) throws -> TextBlockEntry {
        let descriptor = FetchDescriptor<TextBlockEntry>(
            predicate: #Predicate { $0.uuid == id }
        )
        guard let entry = try context.fetch(descriptor).first else {
            throw TextBlockStoreError.notFound
        }
        return entry
    }

    private func normalizedContent(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { throw TextBlockStoreError.emptyContent }
        return value
    }

    private func normalizedTitle(_ raw: String, content: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty == false { return value }
        let firstLine = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "未命名文本块" : String(firstLine.prefix(24))
    }
}
