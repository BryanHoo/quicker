import Foundation
import XCTest
@testable import quicker

final class FileSHA256Tests: XCTestCase {
    func testSHA256HexForFile() throws {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(UUID().uuidString)
        try Data("A".utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            try FileSHA256.sha256Hex(fileURL: url),
            "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd"
        )
    }
}

