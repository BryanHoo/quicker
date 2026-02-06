import XCTest
@testable import quicker

final class AppHotkeyRouteTests: XCTestCase {
    func testMapsHotkeyActionToPanelTarget() {
        XCTAssertEqual(AppHotkeyRoute(action: .clipboardPanel), .clipboard)
        XCTAssertEqual(AppHotkeyRoute(action: .textBlockPanel), .textBlock)
    }
}
