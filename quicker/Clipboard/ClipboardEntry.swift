import Foundation
import SwiftData

@Model
final class ClipboardEntry {
    var text: String
    var createdAt: Date

    var kindRaw: String?
    var rtfData: Data?
    var imagePath: String?
    var contentHash: String?

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}
