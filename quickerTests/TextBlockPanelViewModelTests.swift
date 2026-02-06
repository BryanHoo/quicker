import XCTest
@testable import quicker

@MainActor
final class TextBlockPanelViewModelTests: XCTestCase {
    func testDefaultSelectionIsFirstItem() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make("A"), make("B")])
        XCTAssertEqual(vm.selectedEntry?.title, "A")
    }

    func testArrowDownAtLastItemFlipsPage() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: (0..<7).map { make("\($0)") })
        vm.selectIndexInPage(4)
        vm.moveSelectionDown()
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedEntry?.title, "5")
    }

    func testCmdNumberMapping() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make("A"), make("B")])
        XCTAssertEqual(vm.entryForCmdNumber(2)?.title, "B")
        XCTAssertNil(vm.entryForCmdNumber(3))
    }
}

private func make(_ title: String) -> TextBlockPanelEntry {
    TextBlockPanelEntry(id: UUID(), title: title, content: "content")
}
