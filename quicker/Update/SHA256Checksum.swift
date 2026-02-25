import Foundation

struct SHA256Checksum: Equatable {
    let hashHex: String

    static func parse(from text: String) -> SHA256Checksum? {
        let token = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first
        guard let token else { return nil }
        let hash = token.lowercased()
        guard hash.count == 64 else { return nil }
        guard hash.allSatisfy({ $0.isHexDigit }) else { return nil }
        return SHA256Checksum(hashHex: hash)
    }
}
