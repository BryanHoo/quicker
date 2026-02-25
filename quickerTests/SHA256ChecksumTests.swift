import XCTest
@testable import quicker

final class SHA256ChecksumTests: XCTestCase {
    func testParseShasumOutput() {
        let text = "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd  quicker-v1.0.10.dmg\n"
        XCTAssertEqual(SHA256Checksum.parse(from: text)?.hashHex, "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd")
    }

    func testParseRejectsInvalid() {
        XCTAssertNil(SHA256Checksum.parse(from: "not-a-hash  file.dmg\n"))
    }
}
