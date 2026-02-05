import Foundation

protocol ClipboardStoreInserting {
    func insert(text: String)
    func insertRTF(rtfData: Data, plainText: String, contentHash: String)
    func insertImage(pngData: Data, contentHash: String)
}

struct ClipboardMonitorLogic {
    let ignoreAppStore: IgnoreAppStore
    let clipboardStore: ClipboardStoreInserting

    func handleCapturedChange(_ captured: CapturedClipboardContent, frontmostBundleId: String?) {
        guard ignoreAppStore.isIgnored(bundleIdentifier: frontmostBundleId) == false else { return }

        switch captured.kind {
        case .text:
            clipboardStore.insert(text: captured.plainText)
        case .rtf:
            if let rtf = captured.rtfData {
                clipboardStore.insertRTF(rtfData: rtf, plainText: captured.plainText, contentHash: captured.contentHash)
            } else {
                clipboardStore.insert(text: captured.plainText)
            }
        case .image:
            if let png = captured.pngData {
                clipboardStore.insertImage(pngData: png, contentHash: captured.contentHash)
            }
        }
    }
}

final class ClipboardMonitor {
    private let pasteboard: PasteboardClient
    private let frontmostAppProvider: FrontmostAppProviding
    private let logic: ClipboardMonitorLogic

    private var lastChangeCount: Int
    private var timer: Timer?

    init(
        pasteboard: PasteboardClient,
        frontmostAppProvider: FrontmostAppProviding,
        logic: ClipboardMonitorLogic
    ) {
        self.pasteboard = pasteboard
        self.frontmostAppProvider = frontmostAppProvider
        self.logic = logic
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(pollInterval: TimeInterval = 0.3) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pollOnce() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let snapshot = pasteboard.readSnapshot() else { return }
        guard let captured = PasteboardCaptureLogic().capture(snapshot: snapshot) else { return }
        logic.handleCapturedChange(captured, frontmostBundleId: frontmostAppProvider.frontmostBundleIdentifier)
    }
}
