import XCTest
@testable import quicker

final class ClipboardMonitorLogicTests: XCTestCase {
    func testSkipsWhenFrontmostAppIsIgnored() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let ignoreStore = IgnoreAppStore(userDefaults: defaults)
        try ignoreStore.add(bundleIdentifier: "com.example.secret", displayName: nil, appPath: nil)

        let store = SpyClipboardStore()
        let logic = ClipboardMonitorLogic(ignoreAppStore: ignoreStore, clipboardStore: store)

        logic.handleClipboardTextChange(text: "A", frontmostBundleId: "com.example.secret")
        XCTAssertEqual(store.inserted, [])
    }

    func testInsertsWhenNotIgnored() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let ignoreStore = IgnoreAppStore(userDefaults: defaults)
        let store = SpyClipboardStore()
        let logic = ClipboardMonitorLogic(ignoreAppStore: ignoreStore, clipboardStore: store)

        logic.handleClipboardTextChange(text: "A", frontmostBundleId: "com.example.ok")
        XCTAssertEqual(store.inserted, ["A"])
    }
}

private final class SpyClipboardStore: ClipboardStoreInserting {
    var inserted: [String] = []
    func insert(text: String) {
        inserted.append(text)
    }
}

