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

    func testCmdNumberPastesOnlyWhenExists() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: [makeEntry("A"), makeEntry("B")])
        XCTAssertEqual(vm.entryForCmdNumber(3), nil)
        XCTAssertEqual(vm.entryForCmdNumber(2)?.previewText, "B")
    }
}

private func makeEntry(_ previewText: String) -> ClipboardPanelEntry {
    ClipboardPanelEntry(kind: .text, previewText: previewText, createdAt: Date(timeIntervalSince1970: 0), rtfData: nil, imagePath: nil)
}
