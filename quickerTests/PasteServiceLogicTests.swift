import XCTest
@testable import quicker

final class PasteServiceLogicTests: XCTestCase {
    func testFallsBackWhenNotTrusted() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: false)
        let service = PasteService(writer: writer, eventSender: events, permission: permission, assetStore: FakeAssetStore())

        let result = service.paste(text: "A")
        XCTAssertEqual(writer.writtenStrings, ["A"])
        XCTAssertEqual(writer.writtenKinds, ["text"])
        XCTAssertEqual(events.sentCount, 0)
        XCTAssertEqual(result, .copiedOnly)
    }

    func testSendsCmdVWhenTrusted() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: true)
        let service = PasteService(writer: writer, eventSender: events, permission: permission, assetStore: FakeAssetStore())

        let result = service.paste(text: "A")
        XCTAssertEqual(writer.writtenStrings, ["A"])
        XCTAssertEqual(writer.writtenKinds, ["text"])
        XCTAssertEqual(events.sentCount, 1)
        XCTAssertEqual(result, .pasted)
    }

    func testWritesRtfAndStringWhenPastingRtfEntry() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: true)
        let service = PasteService(writer: writer, eventSender: events, permission: permission, assetStore: FakeAssetStore())

        let entry = ClipboardEntry(text: "hello")
        entry.kindRaw = "rtf"
        entry.rtfData = Data("{\\rtf1\\ansi hello}".utf8)

        _ = service.paste(entry: entry)
        XCTAssertEqual(writer.writtenKinds, ["rtf"])
        XCTAssertEqual(events.sentCount, 1)
    }

    func testFallsBackToStringWhenPastingImageButMissingFile() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: true)
        let service = PasteService(writer: writer, eventSender: events, permission: permission, assetStore: FakeAssetStore())

        let entry = ClipboardEntry(text: "图片")
        entry.kindRaw = "image"
        entry.imagePath = nil

        let result = service.paste(entry: entry)
        XCTAssertEqual(writer.writtenKinds, ["text"])
        XCTAssertEqual(events.sentCount, 0)
        XCTAssertEqual(result, .copiedOnly)
    }
}

private final class SpyPasteboardWriter: PasteboardWriting {
    var writtenKinds: [String] = []
    var writtenStrings: [String] = []

    func writeString(_ string: String) {
        writtenKinds.append("text")
        writtenStrings.append(string)
    }

    func writeRTF(_ rtf: Data, plainText: String) {
        writtenKinds.append("rtf")
        writtenStrings.append(plainText)
    }

    func writePNG(_ png: Data) {
        writtenKinds.append("image")
    }
}

private final class SpyPasteEventSender: PasteEventSending {
    var sentCount = 0
    func sendCmdV() { sentCount += 1 }
}

private struct FakeAccessibilityPermission: AccessibilityPermissionChecking {
    let isTrusted: Bool
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool { isTrusted }
}

private struct FakeAssetStore: ClipboardAssetStoring {
    func saveImage(pngData: Data, contentHash: String) throws -> String { "fake.png" }
    func loadImageData(relativePath: String) throws -> Data { Data() }
    func deleteImage(relativePath: String) throws {}
    func fileURL(relativePath: String) -> URL { URL(fileURLWithPath: "/dev/null") }
}
