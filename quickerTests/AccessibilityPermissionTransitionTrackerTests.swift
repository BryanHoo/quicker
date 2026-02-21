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
}
