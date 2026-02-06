import Foundation

enum TextBlockPanelMapper {
    static func makeEntries(from items: [TextBlockEntry]) -> [TextBlockPanelEntry] {
        items.map { item in
            let title = normalizedTitle(item.title, content: item.content)
            return TextBlockPanelEntry(id: item.uuid, title: title, content: item.content)
        }
    }

    private static func normalizedTitle(_ raw: String, content: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty == false { return value }
        let firstLine = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "未命名文本块" : String(firstLine.prefix(24))
    }
}
