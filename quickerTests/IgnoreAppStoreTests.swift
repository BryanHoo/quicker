import XCTest
@testable import quicker

final class IgnoreAppStoreTests: XCTestCase {
    func testAddAndRemove() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = IgnoreAppStore(userDefaults: defaults)

        try store.add(bundleIdentifier: "com.example.A", displayName: "A", appPath: "/Applications/A.app")
        XCTAssertTrue(store.isIgnored(bundleIdentifier: "com.example.A"))

        store.remove(bundleIdentifier: "com.example.A")
        XCTAssertFalse(store.isIgnored(bundleIdentifier: "com.example.A"))
    }

    func testDedupesByBundleId() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = IgnoreAppStore(userDefaults: defaults)

        try store.add(bundleIdentifier: "com.example.A", displayName: "A", appPath: "/Applications/A.app")
        try store.add(bundleIdentifier: "com.example.A", displayName: "A2", appPath: "/Applications/A2.app")
        XCTAssertEqual(store.all().count, 1)
    }
}

