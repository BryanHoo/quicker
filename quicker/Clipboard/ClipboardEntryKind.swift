import Foundation

enum ClipboardEntryKind: String, Equatable {
    case text
    case rtf
    case image

    init(raw: String?) {
        self = ClipboardEntryKind(rawValue: raw ?? "") ?? .text
    }
}

