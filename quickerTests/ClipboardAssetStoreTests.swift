import Foundation
import XCTest
@testable import quicker

final class ClipboardAssetStoreTests: XCTestCase {
    func testSaveLoadDelete() throws {
        let baseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ClipboardAssetStore(baseURL: baseURL)

        let data = Data([0x01, 0x02, 0x03])
        let rel = try store.saveImage(pngData: data, contentHash: "hash")
        XCTAssertTrue(rel.hasSuffix("hash.png"))

        let loaded = try store.loadImageData(relativePath: rel)
        XCTAssertEqual(loaded, data)

        try store.deleteImage(relativePath: rel)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.fileURL(relativePath: rel).path))
    }
}

