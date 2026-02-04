import XCTest
@testable import quicker

@MainActor
final class ClipboardPanelViewModelTests: XCTestCase {
    func testDefaultSelectionIsFirstItem() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: ["A", "B", "C"])
        XCTAssertEqual(vm.selectedIndexInPage, 0)
        XCTAssertEqual(vm.selectedText, "A")
    }

    func testArrowDownMovesSelection() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: ["A", "B", "C"])
        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedText, "B")
    }

    func testCmdNumberPastesOnlyWhenExists() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: ["A", "B"])
        XCTAssertEqual(vm.textForCmdNumber(3), nil)
        XCTAssertEqual(vm.textForCmdNumber(2), "B")
    }
}

