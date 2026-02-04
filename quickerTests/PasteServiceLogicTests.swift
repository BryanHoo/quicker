import XCTest
@testable import quicker

final class PasteServiceLogicTests: XCTestCase {
    func testFallsBackWhenNotTrusted() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: false)
        let service = PasteService(writer: writer, eventSender: events, permission: permission)

        let result = service.paste(text: "A")
        XCTAssertEqual(writer.written, ["A"])
        XCTAssertEqual(events.sentCount, 0)
        XCTAssertEqual(result, .copiedOnly)
    }

    func testSendsCmdVWhenTrusted() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: true)
        let service = PasteService(writer: writer, eventSender: events, permission: permission)

        let result = service.paste(text: "A")
        XCTAssertEqual(writer.written, ["A"])
        XCTAssertEqual(events.sentCount, 1)
        XCTAssertEqual(result, .pasted)
    }
}

private final class SpyPasteboardWriter: PasteboardWriting {
    var written: [String] = []
    func writeString(_ string: String) { written.append(string) }
}

private final class SpyPasteEventSender: PasteEventSending {
    var sentCount = 0
    func sendCmdV() { sentCount += 1 }
}

private struct FakeAccessibilityPermission: AccessibilityPermissionChecking {
    let isTrusted: Bool
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool { isTrusted }
}

