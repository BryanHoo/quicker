import XCTest
@testable import quicker

@MainActor
final class ClipboardPanelViewModelTests: XCTestCase {
    func testDefaultSelectionIsFirstItem() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: [makeEntry("A"), makeEntry("B"), makeEntry("C")])
        XCTAssertEqual(vm.selectedIndexInPage, 0)
        XCTAssertEqual(vm.selectedEntry?.previewText, "A")
    }

    func testArrowDownMovesSelection() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: [makeEntry("A"), makeEntry("B"), makeEntry("C")])
        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedEntry?.previewText, "B")
    }

    func testArrowDownAtLastItemAutoFlipsToNextPageFirstItem() {
        let vm = ClipboardPanelViewModel(
            pageSize: 5,
            entries: (0..<8).map { makeEntry("\($0)") }
        )

        vm.selectIndexInPage(4)
        vm.moveSelectionDown()

        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedIndexInPage, 0)
        XCTAssertEqual(vm.selectedEntry?.previewText, "5")
    }

    func testArrowUpAtFirstItemAutoFlipsToPreviousPageLastItem() {
        let vm = ClipboardPanelViewModel(
            pageSize: 5,
            entries: (0..<8).map { makeEntry("\($0)") }
        )

        vm.nextPage()
        vm.moveSelectionUp()

        XCTAssertEqual(vm.pageIndex, 0)
        XCTAssertEqual(vm.selectedIndexInPage, 4)
        XCTAssertEqual(vm.selectedEntry?.previewText, "4")
    }

    func testCmdNumberPastesOnlyWhenExists() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: [makeEntry("A"), makeEntry("B")])
        XCTAssertEqual(vm.entryForCmdNumber(3), nil)
        XCTAssertEqual(vm.entryForCmdNumber(2)?.previewText, "B")
    }

    func testSearchQueryFiltersByPreviewText() {
        let vm = ClipboardPanelViewModel(
            pageSize: 5,
            entries: [
                makeEntry("Alpha"),
                makeEntry("Beta KEY"),
                makeEntry("Gamma"),
            ]
        )

        vm.searchQuery = "KEY"

        XCTAssertEqual(vm.visibleEntries.count, 1)
        XCTAssertEqual(vm.selectedEntry?.previewText, "Beta KEY")
    }

    func testSearchQueryResetsPagingAndSelection() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: (0..<9).map { makeEntry("\($0)") })
        vm.nextPage()
        vm.selectIndexInPage(3)
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedIndexInPage, 3)

        vm.searchQuery = "1"

        XCTAssertEqual(vm.pageIndex, 0)
        XCTAssertEqual(vm.selectedIndexInPage, 0)
    }

    func testCmdNumberMappingUsesFilteredEntries() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: [makeEntry("A"), makeEntry("B"), makeEntry("C")])
        vm.searchQuery = "B"
        XCTAssertEqual(vm.entryForCmdNumber(1)?.previewText, "B")
        XCTAssertNil(vm.entryForCmdNumber(2))
    }
}

private func makeEntry(_ previewText: String) -> ClipboardPanelEntry {
    ClipboardPanelEntry(
        kind: .text,
        previewText: previewText,
        createdAt: Date(timeIntervalSince1970: 0),
        rtfData: nil,
        imagePath: nil,
        contentHash: previewText
    )
}
