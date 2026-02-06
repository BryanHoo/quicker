import XCTest
@testable import quicker

final class PreferencesKeysTests: XCTestCase {
    func testDefaultsAreStable() {
        XCTAssertEqual(PreferencesKeys.maxHistoryCount.defaultValue, 200)
        XCTAssertEqual(PreferencesKeys.dedupeAdjacentEnabled.defaultValue, true)
        XCTAssertEqual(PreferencesKeys.hotkey.defaultValue, .default)
        XCTAssertEqual(PreferencesKeys.textBlockHotkey.defaultValue, .textBlockDefault)
    }
}
