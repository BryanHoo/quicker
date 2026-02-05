import Foundation
import SwiftData
import XCTest
@testable import quicker

@MainActor
final class ClipboardStoreImageTests: XCTestCase {
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
}

