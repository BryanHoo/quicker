import XCTest
@testable import quicker

final class SemanticVersionTests: XCTestCase {
    func testParseThreePart() {
        XCTAssertEqual(SemanticVersion("1.0.9"), SemanticVersion(major: 1, minor: 0, patch: 9))
    }

    func testParseWithLeadingV() {
        XCTAssertEqual(SemanticVersion("v2.1.0"), SemanticVersion(major: 2, minor: 1, patch: 0))
    }

    func testCompare() {
        XCTAssertTrue(SemanticVersion("1.0.10")! > SemanticVersion("1.0.9")!)
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(SemanticVersion("1.0"))
        XCTAssertNil(SemanticVersion("abc"))
        XCTAssertNil(SemanticVersion("1.0.x"))
    }
}
