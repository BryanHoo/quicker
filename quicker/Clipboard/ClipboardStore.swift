import Foundation
import SwiftData

@MainActor
final class ClipboardStore {
    private let modelContainer: ModelContainer
    private let preferences: PreferencesStore
    private let assetStore: ClipboardAssetStoring

    init(modelContainer: ModelContainer, preferences: PreferencesStore, assetStore: ClipboardAssetStoring = ClipboardAssetStore()) {
        self.modelContainer = modelContainer
        self.preferences = preferences
        self.assetStore = assetStore
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

        let hash = ContentHash.sha256Hex(Data(trimmed.utf8))

        if preferences.dedupeAdjacentEnabled {
            if let latest = try fetchLatest(limit: 1).first {
                let latestKind = ClipboardEntryKind(raw: latest.kindRaw)
                let latestHash: String? = latest.contentHash ?? {
                    switch latestKind {
                    case .text:
                        let text = latest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return ContentHash.sha256Hex(Data(text.utf8))
                    case .rtf:
                        if let rtf = latest.rtfData { return ContentHash.sha256Hex(rtf) }
                        let text = latest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return ContentHash.sha256Hex(Data(text.utf8))
                    case .image:
                        if let path = latest.imagePath, path.isEmpty == false {
                            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                        }
                        return nil
                    }
                }()

                if latestKind == .text, latestHash == hash {
                    return false
                }
            }
        }

        let entry = ClipboardEntry(text: trimmed, createdAt: now)
        entry.kindRaw = "text"
        entry.contentHash = hash
        context.insert(entry)
        try context.save()

        try trimToMaxCount()
        return true
    }

    @discardableResult
    func insertRTF(rtfData: Data, plainText: String, contentHash: String, now: Date = .now) throws -> Bool {
        let trimmed = plainText.trimmingCharacters(in: .whitespacesAndNewlines)

        if preferences.dedupeAdjacentEnabled {
            if let latest = try fetchLatest(limit: 1).first {
                let latestKind = ClipboardEntryKind(raw: latest.kindRaw)
                let latestHash: String? = latest.contentHash ?? {
                    switch latestKind {
                    case .text:
                        let text = latest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return ContentHash.sha256Hex(Data(text.utf8))
                    case .rtf:
                        if let rtf = latest.rtfData { return ContentHash.sha256Hex(rtf) }
                        let text = latest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return ContentHash.sha256Hex(Data(text.utf8))
                    case .image:
                        if let path = latest.imagePath, path.isEmpty == false {
                            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                        }
                        return nil
                    }
                }()

                if latestKind == .rtf, latestHash == contentHash {
                    return false
                }
            }
        }

        let entry = ClipboardEntry(text: trimmed, createdAt: now)
        entry.kindRaw = "rtf"
        entry.rtfData = rtfData
        entry.contentHash = contentHash
        context.insert(entry)
        try context.save()

        try trimToMaxCount()
        return true
    }

    @discardableResult
    func insertImage(pngData: Data, contentHash: String, now: Date = .now) throws -> Bool {
        if preferences.dedupeAdjacentEnabled {
            if let latest = try fetchLatest(limit: 1).first {
                let latestKind = ClipboardEntryKind(raw: latest.kindRaw)
                let latestHash: String? = latest.contentHash ?? {
                    switch latestKind {
                    case .text:
                        let text = latest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return ContentHash.sha256Hex(Data(text.utf8))
                    case .rtf:
                        if let rtf = latest.rtfData { return ContentHash.sha256Hex(rtf) }
                        let text = latest.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        return ContentHash.sha256Hex(Data(text.utf8))
                    case .image:
                        if let path = latest.imagePath, path.isEmpty == false {
                            return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                        }
                        return nil
                    }
                }()

                if latestKind == .image, latestHash == contentHash {
                    return false
                }
            }
        }

        let relPath = try assetStore.saveImage(pngData: pngData, contentHash: contentHash)

        let entry = ClipboardEntry(text: "图片", createdAt: now)
        entry.kindRaw = "image"
        entry.imagePath = relPath
        entry.contentHash = contentHash
        context.insert(entry)
        try context.save()

        try trimToMaxCount()
        return true
    }

    func clear() throws {
        let all = try context.fetch(FetchDescriptor<ClipboardEntry>())
        let imagePaths: Set<String> = Set(
            all.compactMap { entry in
                guard entry.kindRaw == "image", let path = entry.imagePath else { return nil }
                return path
            }
        )

        for entry in all {
            context.delete(entry)
        }
        try context.save()

        for path in imagePaths {
            try assetStore.deleteImage(relativePath: path)
        }
    }

    func trimToMaxCount() throws {
        let maxCount = max(0, preferences.maxHistoryCount)
        guard maxCount > 0 else {
            try clear()
            return
        }

        let all = try fetchLatest(limit: Int.max)
        guard all.count > maxCount else { return }

        let kept = all.prefix(maxCount)
        let toDelete = all.dropFirst(maxCount)

        let keptImagePaths: Set<String> = Set(
            kept.compactMap { entry in
                guard entry.kindRaw == "image", let path = entry.imagePath else { return nil }
                return path
            }
        )
        let deleteImagePaths: Set<String> = Set(
            toDelete.compactMap { entry in
                guard entry.kindRaw == "image", let path = entry.imagePath else { return nil }
                return path
            }
        )

        for entry in toDelete {
            context.delete(entry)
        }
        try context.save()

        for path in deleteImagePaths.subtracting(keptImagePaths) {
            try assetStore.deleteImage(relativePath: path)
        }
    }
}

extension ClipboardStore: ClipboardStoreInserting {
    func insert(text: String) {
        try? insert(text: text, now: .now)
    }

    func insertRTF(rtfData: Data, plainText: String, contentHash: String) {
        _ = try? insertRTF(rtfData: rtfData, plainText: plainText, contentHash: contentHash, now: .now)
    }

    func insertImage(pngData: Data, contentHash: String) {
        _ = try? insertImage(pngData: pngData, contentHash: contentHash, now: .now)
    }
}
