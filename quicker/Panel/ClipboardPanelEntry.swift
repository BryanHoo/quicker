import Foundation

struct ClipboardPanelEntry: Equatable, Identifiable {
    let kind: ClipboardEntryKind
    let previewText: String
    let createdAt: Date
    let rtfData: Data?
    let imagePath: String?
    let contentHash: String?

    var id: String {
        let timestamp = createdAt.timeIntervalSince1970
        if let contentHash, !contentHash.isEmpty { return "\(contentHash)-\(timestamp)" }
        if let imagePath, !imagePath.isEmpty { return "\(imagePath)-\(timestamp)" }
        return "\(kind.rawValue)-\(timestamp)"
    }
}
