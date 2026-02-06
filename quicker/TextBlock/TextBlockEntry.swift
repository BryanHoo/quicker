import Foundation
import SwiftData

@Model
final class TextBlockEntry {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var content: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        uuid: UUID = UUID(),
        title: String,
        content: String,
        sortOrder: Int,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.uuid = uuid
        self.title = title
        self.content = content
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
