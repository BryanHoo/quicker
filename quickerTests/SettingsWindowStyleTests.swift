import AppKit
import XCTest
@testable import quicker

@MainActor
final class SettingsWindowStyleTests: XCTestCase {
    func testApplyMakesSettingsWindowChromeHiddenButKeepsCloseButton() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        SettingsWindowStyle.apply(to: window)

        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.isOpaque)

        XCTAssertEqual(Double(window.backgroundColor?.alphaComponent ?? 1), 0, accuracy: 0.0001)

        XCTAssertTrue(window.standardWindowButton(.miniaturizeButton)?.isHidden ?? false)
        XCTAssertTrue(window.standardWindowButton(.zoomButton)?.isHidden ?? false)
        XCTAssertFalse(window.standardWindowButton(.closeButton)?.isHidden ?? true)
    }
}
