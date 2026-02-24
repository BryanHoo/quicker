import XCTest
@testable import quicker

final class AccessibilityPermissionTransitionTrackerTests: XCTestCase {
    func testReturnsPasteWhenAlwaysTrusted() {
        let tracker = AccessibilityPermissionTransitionTracker()

        XCTAssertEqual(tracker.decision(for: true), .paste)
        XCTAssertEqual(tracker.decision(for: true), .paste)
    }

    func testReturnsCopyOnlyWhenUntrusted() {
        let tracker = AccessibilityPermissionTransitionTracker()

        XCTAssertEqual(tracker.decision(for: false), .copyOnly)
        XCTAssertEqual(tracker.decision(for: false), .copyOnly)
    }

    func testRequestsRestartOnFirstTrustAfterUntrusted() {
        let tracker = AccessibilityPermissionTransitionTracker()

        _ = tracker.decision(for: false)
        XCTAssertEqual(tracker.decision(for: true), .restartRequired)
    }

    func testRequestsRestartOnlyOnceAfterTrustTransition() {
        let tracker = AccessibilityPermissionTransitionTracker()

        _ = tracker.decision(for: false)
        _ = tracker.decision(for: true)

        XCTAssertEqual(tracker.decision(for: true), .paste)
    }

    func testRequestsRestartAgainAfterBecomingUntrustedThenTrustedAgain() {
        let tracker = AccessibilityPermissionTransitionTracker()

        _ = tracker.decision(for: false)
        _ = tracker.decision(for: true)
        _ = tracker.decision(for: false)

        XCTAssertEqual(tracker.decision(for: true), .restartRequired)
    }

    func testSkipsRestartWhenPermissionWasTrustedInPreviousSession() {
        let history = SpyAccessibilityPermissionTrustHistoryStore(hasEverBeenTrusted: true)
        let tracker = AccessibilityPermissionTransitionTracker(trustHistoryStore: history)

        _ = tracker.decision(for: false)

        XCTAssertEqual(tracker.decision(for: true), .paste)
    }

    func testRecordsTrustedStateWhenPermissionBecomesTrusted() {
        let history = SpyAccessibilityPermissionTrustHistoryStore(hasEverBeenTrusted: false)
        let tracker = AccessibilityPermissionTransitionTracker(trustHistoryStore: history)

        XCTAssertFalse(history.hasEverBeenTrusted)

        _ = tracker.decision(for: true)

        XCTAssertTrue(history.hasEverBeenTrusted)
    }
}

private final class SpyAccessibilityPermissionTrustHistoryStore: AccessibilityPermissionTrustHistoryStoring {
    private(set) var hasEverBeenTrusted: Bool

    init(hasEverBeenTrusted: Bool) {
        self.hasEverBeenTrusted = hasEverBeenTrusted
    }

    func markTrusted() {
        hasEverBeenTrusted = true
    }
}
