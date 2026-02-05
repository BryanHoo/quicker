import Foundation
import XCTest
@testable import quicker

final class PasteboardCaptureLogicTests: XCTestCase {
    func testSkipsWhenTransientMarkerPresent() {
        let snapshot = PasteboardSnapshot(items: [
            .init(typeIdentifiers: ["org.nspasteboard.TransientType"], pngData: nil, tiffData: nil, rtfData: nil, string: "A"),
        ])
        XCTAssertNil(PasteboardCaptureLogic().capture(snapshot: snapshot))
    }

    func testPriorityImageOverRtfOverString() throws {
        let png = try XCTUnwrap(
            Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7+5S8AAAAASUVORK5CYII=")
        )
        let rtf = Data("{\\rtf1\\ansi hello}".utf8)

        let snapshot = PasteboardSnapshot(items: [
            .init(typeIdentifiers: ["public.rtf", "public.png"], pngData: png, tiffData: nil, rtfData: rtf, string: "fallback"),
        ])

        let captured = try XCTUnwrap(PasteboardCaptureLogic().capture(snapshot: snapshot))
        XCTAssertEqual(captured.kind, .image)
        XCTAssertEqual(captured.contentHash, ContentHash.sha256Hex(png))
    }

    func testMultipleStringItemsJoinsWithNewline() throws {
        let snapshot = PasteboardSnapshot(items: [
            .init(typeIdentifiers: ["public.utf8-plain-text"], pngData: nil, tiffData: nil, rtfData: nil, string: "A"),
            .init(typeIdentifiers: ["public.utf8-plain-text"], pngData: nil, tiffData: nil, rtfData: nil, string: "B"),
        ])
        let captured = try XCTUnwrap(PasteboardCaptureLogic().capture(snapshot: snapshot))
        XCTAssertEqual(captured.kind, .text)
        XCTAssertEqual(captured.plainText, "A\nB")
    }
}

