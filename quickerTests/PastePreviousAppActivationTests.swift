import XCTest
@testable import quicker

@MainActor
final class PastePreviousAppActivationTests: XCTestCase {
    func testPasteClipboardEntryActivatesPreviousAppIgnoringOtherAppsWhenTrusted() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: FakeAccessibilityPermission(isTrusted: true)
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
    }

    func testPasteTextBlockEntryActivatesPreviousAppIgnoringOtherAppsWhenTrusted() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

        AppState.pasteTextBlockEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: FakeAccessibilityPermission(isTrusted: true)
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
    }

    func testPasteClipboardEntryChecksAccessibilityPermissionWithPromptEnabled() {
        let pasteService = makePasteService(isTrusted: true)
        let permission = RecordingAccessibilityPermission(isTrusted: true)
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

        AppState.pasteClipboardEntry(
            entry,
            previousApp: nil,
            pasteService: pasteService,
            permission: permission
        )

        XCTAssertEqual(permission.lastPromptIfNeeded, true)
    }

    func testPasteTextBlockEntryChecksAccessibilityPermissionWithPromptEnabled() {
        let pasteService = makePasteService(isTrusted: true)
        let permission = RecordingAccessibilityPermission(isTrusted: true)
        let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

        AppState.pasteTextBlockEntry(
            entry,
            previousApp: nil,
            pasteService: pasteService,
            permission: permission
        )

        XCTAssertEqual(permission.lastPromptIfNeeded, true)
    }
}

private final class SpyRunningApplication: RunningApplicationActivating {
    private(set) var activatedOptions: NSApplication.ActivationOptions?

    func activate(options: NSApplication.ActivationOptions) -> Bool {
        activatedOptions = options
        return true
    }
}

private func makePasteService(isTrusted: Bool) -> PasteService {
    PasteService(
        writer: SpyPasteboardWriter(),
        eventSender: SpyPasteEventSender(),
        permission: FakeAccessibilityPermission(isTrusted: isTrusted),
        assetStore: FakeAssetStore()
    )
}

private final class SpyPasteboardWriter: PasteboardWriting {
    func writeString(_ string: String) {}
    func writeRTF(_ rtf: Data, plainText: String) {}
    func writePNG(_ png: Data) {}
}

private final class SpyPasteEventSender: PasteEventSending {
    func sendCmdV() {}
}

private struct FakeAccessibilityPermission: AccessibilityPermissionChecking {
    let isTrusted: Bool
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool { isTrusted }
}

private final class RecordingAccessibilityPermission: AccessibilityPermissionChecking {
    private(set) var lastPromptIfNeeded: Bool?
    private let isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        lastPromptIfNeeded = promptIfNeeded
        return isTrusted
    }
}

private struct FakeAssetStore: ClipboardAssetStoring {
    func saveImage(pngData: Data, contentHash: String) throws -> String { "fake.png" }
    func loadImageData(relativePath: String) throws -> Data { Data() }
    func deleteImage(relativePath: String) throws {}
    func fileURL(relativePath: String) -> URL { URL(fileURLWithPath: "/dev/null") }
}
