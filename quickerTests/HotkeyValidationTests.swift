import Carbon
import XCTest
@testable import quicker

final class HotkeyValidationTests: XCTestCase {
    func testRejectsWhenMissingCommand() {
        let candidate = Hotkey(keyCode: 11, modifiers: UInt32(shiftKey))
        XCTAssertEqual(
            HotkeyValidation.validateTextBlock(candidate, clipboardHotkey: .default),
            .missingCommand
        )
    }

    func testRejectsWhenSameAsClipboardHotkey() {
        XCTAssertEqual(
            HotkeyValidation.validateTextBlock(.default, clipboardHotkey: .default),
            .conflictsWithClipboard
        )
    }

    func testAcceptsCmdShiftB() {
        XCTAssertEqual(
            HotkeyValidation.validateTextBlock(.textBlockDefault, clipboardHotkey: .default),
            nil
        )
    }
}
