import Foundation
import XCTest
@testable import quicker

final class MenuBarLocalizationTests: XCTestCase {
    func testMenuBarExtraMenuIsSimplifiedChinese() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let appFileURL = projectRoot.appendingPathComponent("quicker/quickerApp.swift")

        let source = try String(contentsOf: appFileURL, encoding: .utf8)

        XCTAssertFalse(source.contains("Open Clipboard Panel"))
        XCTAssertFalse(source.contains("Open Text Block Panel"))
        XCTAssertFalse(source.contains("Settings…"))
        XCTAssertFalse(source.contains("Clear History"))
        XCTAssertFalse(source.contains("Quit"))

        XCTAssertTrue(source.contains("打开剪贴板面板"))
        XCTAssertTrue(source.contains("打开文本块面板"))
        XCTAssertTrue(source.contains("偏好设置…"))
        XCTAssertTrue(source.contains("清空历史"))
        XCTAssertTrue(source.contains("退出"))
    }
}

