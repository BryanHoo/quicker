import Foundation
import SwiftData
import XCTest
@testable import quicker

@MainActor
final class ClipboardStoreRtfTests: XCTestCase {
    func testInsertRtfSetsFields() throws {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])

        let prefs = PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!)
        let store = ClipboardStore(
            modelContainer: container,
            preferences: prefs,
            assetStore: ClipboardAssetStore(
                baseURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString, isDirectory: true)
            )
        )

        let rtf = Data("{\\rtf1\\ansi hello}".utf8)
        let hash = ContentHash.sha256Hex(rtf)

        _ = try store.insertRTF(rtfData: rtf, plainText: "hello", contentHash: hash)

        let entry = try XCTUnwrap(store.fetchLatest(limit: 1).first)
        XCTAssertEqual(entry.kindRaw, "rtf")
        XCTAssertEqual(entry.text, "hello")
        XCTAssertEqual(entry.rtfData, rtf)
        XCTAssertEqual(entry.contentHash, hash)
    }
}

