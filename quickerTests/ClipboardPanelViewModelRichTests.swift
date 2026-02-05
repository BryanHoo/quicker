import XCTest
@testable import quicker

@MainActor
final class ClipboardPanelViewModelRichTests: XCTestCase {
    func testSelectionAndCmdNumberWorksWithEntries() {
        let vm = ClipboardPanelViewModel(pageSize: 5)
        vm.setEntries((0..<6).map { ClipboardPanelEntry(kind: .text, previewText: "\($0)", rtfData: nil, imagePath: nil) })
        XCTAssertEqual(vm.selectedEntry?.previewText, "0")
        XCTAssertEqual(vm.entryForCmdNumber(1)?.previewText, "0")
        vm.nextPage()
        XCTAssertEqual(vm.selectedEntry?.previewText, "5")
    }
}

