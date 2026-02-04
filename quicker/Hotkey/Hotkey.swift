import Carbon
import Foundation

struct Hotkey: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = Hotkey(
        keyCode: 9, // v
        modifiers: UInt32(cmdKey | shiftKey)
    )
}

