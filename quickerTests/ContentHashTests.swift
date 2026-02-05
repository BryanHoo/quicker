import Foundation
import XCTest
@testable import quicker

final class ContentHashTests: XCTestCase {
    func testSha256HexForData() {
        let data = Data("A".utf8)
        XCTAssertEqual(
            ContentHash.sha256Hex(data),
            "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd"
        )
    }
}

