import XCTest
@testable import quicker

final class PanelKeyCommandTests: XCTestCase {
    func testEscCloses() {
        let cmd = PanelKeyCommand.interpret(.init(keyCode: 53), pageSize: 5)
        XCTAssertEqual(cmd, .close)
    }

    func testReturnConfirms() {
        let cmd = PanelKeyCommand.interpret(.init(keyCode: 36), pageSize: 5)
        XCTAssertEqual(cmd, .confirm)
    }

    func testArrowKeys() {
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 126), pageSize: 5), .moveUp)
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 125), pageSize: 5), .moveDown)
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 123), pageSize: 5), .previousPage)
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 124), pageSize: 5), .nextPage)
    }

    func testCmdCommaOpensSettings() {
        let cmd = PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: ",", isCommandDown: true), pageSize: 5)
        XCTAssertEqual(cmd, .openSettings)
    }

    func testCmdNumberPastesWithinPageSize() {
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: "1", isCommandDown: true), pageSize: 5), .pasteCmdNumber(1))
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: "5", isCommandDown: true), pageSize: 5), .pasteCmdNumber(5))
        XCTAssertNil(PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: "6", isCommandDown: true), pageSize: 5))
    }

    func testUnhandledReturnsNil() {
        XCTAssertNil(PanelKeyCommand.interpret(.init(keyCode: 48), pageSize: 5)) // Tab
    }
}
