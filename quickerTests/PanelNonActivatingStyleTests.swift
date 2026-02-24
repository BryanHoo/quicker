import AppKit
import XCTest
@testable import quicker

@MainActor
final class PanelNonActivatingStyleTests: XCTestCase {
    func testClipboardPanelUsesNonActivatingStyleMask() {
        let viewModel = ClipboardPanelViewModel(pageSize: 5)
        let controller = PanelController(viewModel: viewModel, onPaste: { _, _ in })

        controller.show()
        defer { controller.close() }

        pumpMainRunLoop()

        guard let panel = panelWindow(with: PanelWindowIdentifier.clipboardPanel) else {
            XCTFail("Expected clipboard panel window to exist")
            return
        }

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
    }

    func testTextBlockPanelUsesNonActivatingStyleMask() {
        let viewModel = TextBlockPanelViewModel(pageSize: 5)
        let controller = TextBlockPanelController(viewModel: viewModel, onInsert: { _, _ in })

        controller.show()
        defer { controller.close() }

        pumpMainRunLoop()

        guard let panel = panelWindow(with: PanelWindowIdentifier.textBlockPanel) else {
            XCTFail("Expected text block panel window to exist")
            return
        }

        XCTAssertTrue(panel.styleMask.contains(.nonactivatingPanel))
    }

    private func panelWindow(with identifier: NSUserInterfaceItemIdentifier) -> NSPanel? {
        NSApp.windows.first {
            $0.identifier == identifier && $0 is NSPanel
        } as? NSPanel
    }

    private func pumpMainRunLoop() {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.02))
    }
}
