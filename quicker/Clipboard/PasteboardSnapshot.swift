import Foundation

struct PasteboardSnapshot: Equatable {
    struct Item: Equatable {
        let typeIdentifiers: [String]
        let pngData: Data?
        let tiffData: Data?
        let rtfData: Data?
        let string: String?
    }

    let items: [Item]
}

