import Foundation

struct ClipboardPanelEntry: Equatable {
    let kind: ClipboardEntryKind
    let previewText: String
    let createdAt: Date
    let rtfData: Data?
    let imagePath: String?
}
