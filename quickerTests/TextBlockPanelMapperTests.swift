import XCTest
@testable import quicker

@MainActor
final class TextBlockPanelMapperTests: XCTestCase {
    func testMapperFallsBackToFirstLineWhenTitleEmpty() {
        let entry = TextBlockEntry(title: "   ", content: "第一行\n第二行", sortOrder: 0)
        let mapped = TextBlockPanelMapper.makeEntries(from: [entry])

        XCTAssertEqual(mapped.count, 1)
        XCTAssertEqual(mapped[0].title, "第一行")
        XCTAssertEqual(mapped[0].content, "第一行\n第二行")
    }
}
