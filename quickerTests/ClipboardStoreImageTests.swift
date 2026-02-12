import Foundation
import SwiftData
import XCTest
@testable import quicker

@MainActor
final class ClipboardStoreImageTests: XCTestCase {
    func testInsertImagePersistsPath() throws {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let assets = ClipboardAssetStore(baseURL: baseURL)

        let prefs = PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = ClipboardStore(modelContainer: container, preferences: prefs, assetStore: assets)

        let png = Data([0x01, 0x02])
        let hash = ContentHash.sha256Hex(png)

        _ = try store.insertImage(pngData: png, contentHash: hash)

        let entry = try XCTUnwrap(store.fetchLatest(limit: 1).first)
        XCTAssertEqual(entry.kindRaw, "image")
        let rel = try XCTUnwrap(entry.imagePath)
        XCTAssertTrue(FileManager.default.fileExists(atPath: assets.fileURL(relativePath: rel).path))
    }

    func testClearDeletesUnreferencedImageFiles() throws {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let assets = ClipboardAssetStore(baseURL: baseURL)

        let prefs = PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = ClipboardStore(modelContainer: container, preferences: prefs, assetStore: assets)

        let png = Data([0x01, 0x02])
        let hash = ContentHash.sha256Hex(png)
        let rel = try assets.saveImage(pngData: png, contentHash: hash)

        let entry = ClipboardEntry(text: "图片")
        entry.kindRaw = "image"
        entry.imagePath = rel
        entry.contentHash = hash
        container.mainContext.insert(entry)
        try container.mainContext.save()

        try store.clear()
        XCTAssertFalse(FileManager.default.fileExists(atPath: assets.fileURL(relativePath: rel).path))
    }

    func testMaxHistoryCountTrimsImageAndDeletesFile() throws {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let assets = ClipboardAssetStore(baseURL: baseURL)

        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = PreferencesStore(userDefaults: defaults)
        prefs.maxHistoryCount = 1
        prefs.dedupeAdjacentEnabled = false

        let store = ClipboardStore(modelContainer: container, preferences: prefs, assetStore: assets)

        let png1 = Data([0x01])
        let hash1 = ContentHash.sha256Hex(png1)
        _ = try store.insertImage(pngData: png1, contentHash: hash1)
        let rel1 = "\(hash1).png"
        XCTAssertTrue(FileManager.default.fileExists(atPath: assets.fileURL(relativePath: rel1).path))

        let png2 = Data([0x02])
        let hash2 = ContentHash.sha256Hex(png2)
        _ = try store.insertImage(pngData: png2, contentHash: hash2)

        let latest = try store.fetchLatest(limit: 10)
        XCTAssertEqual(latest.count, 1)
        XCTAssertEqual(latest.first?.contentHash, hash2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: assets.fileURL(relativePath: rel1).path))
    }
}
