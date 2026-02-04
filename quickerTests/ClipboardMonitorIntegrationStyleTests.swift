import XCTest
@testable import quicker

final class ClipboardMonitorIntegrationStyleTests: XCTestCase {
    func testPollInsertsWhenChangeCountAdvances() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let ignoreStore = IgnoreAppStore(userDefaults: defaults)
        let store = SpyInsertStore()

        let pasteboard = FakePasteboardClient()
        let frontmost = FakeFrontmostAppProvider(bundleId: "com.example.ok")

        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            frontmostAppProvider: frontmost,
            logic: ClipboardMonitorLogic(ignoreAppStore: ignoreStore, clipboardStore: store)
        )

        pasteboard.set(text: "A", changeCount: 1)
        monitor.pollOnce()

        XCTAssertEqual(store.inserted, ["A"])
    }
}

private final class SpyInsertStore: ClipboardStoreInserting {
    var inserted: [String] = []
    func insert(text: String) { inserted.append(text) }
}

private final class FakePasteboardClient: PasteboardClient {
    private(set) var changeCount: Int = 0
    private var text: String?
    func set(text: String?, changeCount: Int) {
        self.text = text
        self.changeCount = changeCount
    }
    func readString() -> String? { text }
}

private struct FakeFrontmostAppProvider: FrontmostAppProviding {
    let bundleId: String?
    var frontmostBundleIdentifier: String? { bundleId }
}

