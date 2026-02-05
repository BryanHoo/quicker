import XCTest
@testable import quicker

final class ClipboardEntryKindTests: XCTestCase {
    func testParsesRaw() {
        XCTAssertEqual(ClipboardEntryKind(raw: nil), .text)
        XCTAssertEqual(ClipboardEntryKind(raw: "text"), .text)
        XCTAssertEqual(ClipboardEntryKind(raw: "rtf"), .rtf)
        XCTAssertEqual(ClipboardEntryKind(raw: "image"), .image)
        XCTAssertEqual(ClipboardEntryKind(raw: "unknown"), .text)
    }
}

