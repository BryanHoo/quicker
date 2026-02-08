import XCTest
@testable import quicker

@MainActor
final class PastePreviousAppActivationTests: XCTestCase {
    func testPasteClipboardEntryActivatesPreviousAppIgnoringOtherAppsWhenTrusted() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let toast = ToastPresenter()
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil)

        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            toast: toast,
            permission: FakeAccessibilityPermission(isTrusted: true)
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
    }

    func testPasteTextBlockEntryActivatesPreviousAppIgnoringOtherAppsWhenTrusted() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let toast = ToastPresenter()
        let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

        AppState.pasteTextBlockEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            toast: toast,
            permission: FakeAccessibilityPermission(isTrusted: true)
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
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

private struct FakeAssetStore: ClipboardAssetStoring {
    func saveImage(pngData: Data, contentHash: String) throws -> String { "fake.png" }
    func loadImageData(relativePath: String) throws -> Data { Data() }
    func deleteImage(relativePath: String) throws {}
    func fileURL(relativePath: String) -> URL { URL(fileURLWithPath: "/dev/null") }
}

