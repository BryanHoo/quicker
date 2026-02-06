import Carbon
import XCTest
@testable import quicker

@MainActor
final class PreferencesStoreTests: XCTestCase {
    func testDefaultValues() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        let store = PreferencesStore(userDefaults: defaults)

        XCTAssertEqual(store.maxHistoryCount, PreferencesKeys.maxHistoryCount.defaultValue)
        XCTAssertEqual(store.dedupeAdjacentEnabled, PreferencesKeys.dedupeAdjacentEnabled.defaultValue)
        XCTAssertEqual(store.hotkey, PreferencesKeys.hotkey.defaultValue)
        XCTAssertEqual(store.textBlockHotkey, PreferencesKeys.textBlockHotkey.defaultValue)
    }

    func testPersistAndReadBack() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
        let store = PreferencesStore(userDefaults: defaults)

        store.maxHistoryCount = 10
        store.dedupeAdjacentEnabled = false
        store.hotkey = Hotkey(keyCode: 1, modifiers: 0)
        store.textBlockHotkey = Hotkey(keyCode: 11, modifiers: UInt32(cmdKey | shiftKey))

        XCTAssertEqual(store.maxHistoryCount, 10)
        XCTAssertEqual(store.dedupeAdjacentEnabled, false)
        XCTAssertEqual(store.hotkey, Hotkey(keyCode: 1, modifiers: 0))
        XCTAssertEqual(store.textBlockHotkey, Hotkey(keyCode: 11, modifiers: UInt32(cmdKey | shiftKey)))
    }
}
