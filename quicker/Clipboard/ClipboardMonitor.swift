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

