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
            let types = item.types
            let typeSet = Set(types)
            return PasteboardSnapshot.Item(
                typeIdentifiers: types.map(\.rawValue),
                pngData: typeSet.contains(.png) ? item.data(forType: .png) : nil,
                tiffData: typeSet.contains(.tiff) ? item.data(forType: .tiff) : nil,
                rtfData: typeSet.contains(.rtf) ? item.data(forType: .rtf) : nil,
                string: typeSet.contains(.string) ? item.string(forType: .string) : nil
            )
        })
    }
}
