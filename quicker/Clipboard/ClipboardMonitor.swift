import Foundation

protocol ClipboardStoreInserting {
    func insert(text: String)
}

struct ClipboardMonitorLogic {
    let ignoreAppStore: IgnoreAppStore
    let clipboardStore: ClipboardStoreInserting

    func handleClipboardTextChange(text: String, frontmostBundleId: String?) {
        guard ignoreAppStore.isIgnored(bundleIdentifier: frontmostBundleId) == false else { return }
        clipboardStore.insert(text: text)
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

        guard let text = pasteboard.readString() else { return }
        logic.handleClipboardTextChange(text: text, frontmostBundleId: frontmostAppProvider.frontmostBundleIdentifier)
    }
}
