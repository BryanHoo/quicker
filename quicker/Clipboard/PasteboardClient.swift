import AppKit

protocol PasteboardClient {
    var changeCount: Int { get }
    func readSnapshot() -> PasteboardSnapshot?
}

struct SystemPasteboardClient: PasteboardClient {
    private let pasteboard = NSPasteboard.general

    var changeCount: Int { pasteboard.changeCount }

    func readSnapshot() -> PasteboardSnapshot? {
        guard let items = pasteboard.pasteboardItems, items.isEmpty == false else { return nil }

        return PasteboardSnapshot(items: items.map { item in
            PasteboardSnapshot.Item(
                typeIdentifiers: item.types.map(\.rawValue),
                pngData: item.data(forType: .png),
                tiffData: item.data(forType: .tiff),
                rtfData: item.data(forType: .rtf),
                string: item.string(forType: .string)
            )
        })
    }
}
