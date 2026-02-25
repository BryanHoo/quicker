import XCTest
@testable import quicker

@MainActor
final class PastePreviousAppActivationTests: XCTestCase {
    func testPasteClipboardEntryActivatesPreviousAppIgnoringOtherAppsWhenTrusted() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: FakeAccessibilityPermission(isTrusted: true),
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
    }

    func testPasteTextBlockEntryActivatesPreviousAppIgnoringOtherAppsWhenTrusted() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

        AppState.pasteTextBlockEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: FakeAccessibilityPermission(isTrusted: true),
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
    }

    func testPasteClipboardEntryChecksAccessibilityPermissionWithPromptEnabled() {
        let pasteService = makePasteService(isTrusted: true)
        let permission = RecordingAccessibilityPermission(isTrusted: true)
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

        AppState.pasteClipboardEntry(
            entry,
            previousApp: nil,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(permission.lastPromptIfNeeded, true)
    }

    func testPasteTextBlockEntryChecksAccessibilityPermissionWithPromptEnabled() {
        let pasteService = makePasteService(isTrusted: true)
        let permission = RecordingAccessibilityPermission(isTrusted: true)
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

        AppState.pasteTextBlockEntry(
            entry,
            previousApp: nil,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(permission.lastPromptIfNeeded, true)
    }

    func testPasteClipboardEntryPromptsRelaunchOnFirstTrustAfterUntrusted() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let permission = SequenceAccessibilityPermission(values: [false, true])
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )
        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        let expectation = expectation(description: "Delayed relaunch prompt")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.3)

        XCTAssertEqual(relaunchCoordinator.promptCount, 1)
    }

    func testPasteClipboardEntryActivatesPreviousAppWhenRestartRequired() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let permission = SequenceAccessibilityPermission(values: [false, true])
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )
        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
    }

    func testPasteTextBlockEntryActivatesPreviousAppWhenRestartRequired() {
        let previousApp = SpyRunningApplication()
        let pasteService = makePasteService(isTrusted: true)
        let permission = SequenceAccessibilityPermission(values: [false, true])
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

        AppState.pasteTextBlockEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )
        AppState.pasteTextBlockEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(previousApp.activatedOptions?.contains(.activateIgnoringOtherApps), true)
    }

    func testPasteClipboardEntryDelaysPasteAndPromptWhenRestartRequired() {
        let previousApp = SpyRunningApplication()
        let writer = CountingPasteboardWriter()
        let pasteService = makePasteService(isTrusted: true, writer: writer)
        let permission = SequenceAccessibilityPermission(values: [false, true])
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )
        AppState.pasteClipboardEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(writer.stringWriteCount, 1)
        XCTAssertEqual(relaunchCoordinator.promptCount, 0)

        let expectation = expectation(description: "Delayed restartRequired paste")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.3)

        XCTAssertEqual(writer.stringWriteCount, 2)
        XCTAssertEqual(relaunchCoordinator.promptCount, 1)
    }

    func testPasteTextBlockEntryDelaysPasteAndPromptWhenRestartRequired() {
        let previousApp = SpyRunningApplication()
        let writer = CountingPasteboardWriter()
        let pasteService = makePasteService(isTrusted: true, writer: writer)
        let permission = SequenceAccessibilityPermission(values: [false, true])
        let tracker = AccessibilityPermissionTransitionTracker()
        let relaunchCoordinator = SpyRelaunchCoordinator()
        let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

        AppState.pasteTextBlockEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )
        AppState.pasteTextBlockEntry(
            entry,
            previousApp: previousApp,
            pasteService: pasteService,
            permission: permission,
            permissionTransitionTracker: tracker,
            relaunchCoordinator: relaunchCoordinator
        )

        XCTAssertEqual(writer.stringWriteCount, 1)
        XCTAssertEqual(relaunchCoordinator.promptCount, 0)

        let expectation = expectation(description: "Delayed restartRequired text block paste")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 0.3)

        XCTAssertEqual(writer.stringWriteCount, 2)
        XCTAssertEqual(relaunchCoordinator.promptCount, 1)
    }
}

private final class SpyRunningApplication: RunningApplicationActivating {
    private(set) var activatedOptions: NSApplication.ActivationOptions?

    func activate(options: NSApplication.ActivationOptions) -> Bool {
        activatedOptions = options
        return true
    }
}

private func makePasteService(
    isTrusted: Bool,
    writer: PasteboardWriting = SpyPasteboardWriter(),
    eventSender: PasteEventSending = SpyPasteEventSender()
) -> PasteService {
    PasteService(
        writer: writer,
        eventSender: eventSender,
        permission: FakeAccessibilityPermission(isTrusted: isTrusted),
        assetStore: FakeAssetStore()
    )
}

private final class SpyPasteboardWriter: PasteboardWriting {
    func writeString(_ string: String, skipCapture: Bool) {}
    func writeRTF(_ rtf: Data, plainText: String, skipCapture: Bool) {}
    func writePNG(_ png: Data, skipCapture: Bool) {}
}

private final class SpyPasteEventSender: PasteEventSending {
    func sendCmdV() {}
}

private final class CountingPasteboardWriter: PasteboardWriting {
    private(set) var stringWriteCount = 0

    func writeString(_ string: String, skipCapture: Bool) {
        stringWriteCount += 1
    }

    func writeRTF(_ rtf: Data, plainText: String, skipCapture: Bool) {
        stringWriteCount += 1
    }

    func writePNG(_ png: Data, skipCapture: Bool) {
        stringWriteCount += 1
    }
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

private final class SequenceAccessibilityPermission: AccessibilityPermissionChecking {
    private let values: [Bool]
    private var currentIndex = 0

    init(values: [Bool]) {
        self.values = values
    }

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        guard currentIndex < values.count else { return values.last ?? false }
        defer { currentIndex += 1 }
        return values[currentIndex]
    }
}

private final class SpyRelaunchCoordinator: AccessibilityPermissionRelaunchCoordinating {
    private(set) var promptCount = 0

    func promptForRelaunchAfterPermissionGrant() {
        promptCount += 1
    }
}

private struct FakeAssetStore: ClipboardAssetStoring {
    func saveImage(pngData: Data, contentHash: String) throws -> String { "fake.png" }
    func loadImageData(relativePath: String) throws -> Data { Data() }
    func deleteImage(relativePath: String) throws {}
    func fileURL(relativePath: String) -> URL { URL(fileURLWithPath: "/dev/null") }
}
