import Foundation
import SwiftData

@MainActor
final class ClipboardStore {
    private let modelContainer: ModelContainer
    private let preferences: PreferencesStore

    init(modelContainer: ModelContainer, preferences: PreferencesStore) {
        self.modelContainer = modelContainer
        self.preferences = preferences
    }

    private var context: ModelContext { modelContainer.mainContext }

    func fetchLatest(limit: Int) throws -> [ClipboardEntry] {
        var descriptor = FetchDescriptor<ClipboardEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    @discardableResult
    func insert(text: String, now: Date = .now) throws -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if preferences.dedupeAdjacentEnabled {
            if let latest = try fetchLatest(limit: 1).first, latest.text == trimmed {
                return false
            }
        }

        context.insert(ClipboardEntry(text: trimmed, createdAt: now))
        try context.save()

        try trimToMaxCount()
        return true
    }

    func clear() throws {
        let all = try context.fetch(FetchDescriptor<ClipboardEntry>())
        for entry in all {
            context.delete(entry)
        }
        try context.save()
    }

    func trimToMaxCount() throws {
        let maxCount = max(0, preferences.maxHistoryCount)
        guard maxCount > 0 else {
            try clear()
            return
        }

        let all = try fetchLatest(limit: Int.max)
        guard all.count > maxCount else { return }

        for entry in all.dropFirst(maxCount) {
            context.delete(entry)
        }
        try context.save()
    }
}

extension ClipboardStore: ClipboardStoreInserting {
    func insert(text: String) {
        try? insert(text: text, now: .now)
    }
}
