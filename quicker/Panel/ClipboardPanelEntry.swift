import Foundation

struct ClipboardPanelEntry: Equatable {
    let kind: ClipboardEntryKind
    let previewText: String
    let rtfData: Data?
    let imagePath: String?
}

