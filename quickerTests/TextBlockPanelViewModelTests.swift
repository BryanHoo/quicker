import XCTest
@testable import quicker

@MainActor
final class TextBlockPanelViewModelTests: XCTestCase {
    func testDefaultSelectionIsFirstItem() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make(title: "A"), make(title: "B")])
        XCTAssertEqual(vm.selectedEntry?.title, "A")
    }

    func testArrowDownAtLastItemFlipsPage() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: (0..<7).map { make(title: "\($0)") })
        vm.selectIndexInPage(4)
        vm.moveSelectionDown()
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedEntry?.title, "5")
    }

    func testCmdNumberMapping() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make(title: "A"), make(title: "B")])
        XCTAssertEqual(vm.entryForCmdNumber(2)?.title, "B")
        XCTAssertNil(vm.entryForCmdNumber(3))
    }

    func testSearchQueryFiltersByTitleOrContent() {
        let vm = TextBlockPanelViewModel(
            pageSize: 5,
            entries: [
                make(title: "Alpha", content: "first line"),
                make(title: "Beta", content: "contains KEY"),
                make(title: "KEY in title", content: "zzz"),
            ]
        )

        vm.searchQuery = "KEY"

        XCTAssertEqual(vm.visibleEntries.count, 2)
        XCTAssertEqual(vm.selectedEntry?.title, "Beta")
    }

    func testSearchQueryResetsPagingAndSelection() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: (0..<9).map { make(title: "\($0)") })
        vm.nextPage()
        vm.selectIndexInPage(2)
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedIndexInPage, 2)

        vm.searchQuery = "1"

        XCTAssertEqual(vm.pageIndex, 0)
        XCTAssertEqual(vm.selectedIndexInPage, 0)
    }

    func testCmdNumberMappingUsesFilteredEntries() {
        let vm = TextBlockPanelViewModel(
            pageSize: 5,
            entries: [
                make(title: "A"),
                make(title: "B"),
                make(title: "C"),
            ]
        )

        vm.searchQuery = "B"

        XCTAssertEqual(vm.entryForCmdNumber(1)?.title, "B")
        XCTAssertNil(vm.entryForCmdNumber(2))
    }
}

private func make(title: String, content: String = "content") -> TextBlockPanelEntry {
    TextBlockPanelEntry(id: UUID(), title: title, content: content)
}
