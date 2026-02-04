import AppKit

protocol PasteboardClient {
    var changeCount: Int { get }
    func readString() -> String?
}

struct SystemPasteboardClient: PasteboardClient {
    private let pasteboard = NSPasteboard.general

    var changeCount: Int { pasteboard.changeCount }

    func readString() -> String? {
        pasteboard.string(forType: .string)
    }
}

