import Carbon
import Foundation

enum HotkeyRouteCodec {
    static let signature = OSType(0x514B484B) // "QKHK"

    static func makeID(for action: HotkeyAction) -> EventHotKeyID {
        EventHotKeyID(signature: signature, id: action.rawValue)
    }

    static func decode(_ id: EventHotKeyID) -> HotkeyAction? {
        guard id.signature == signature else { return nil }
        return HotkeyAction(rawValue: id.id)
    }
}
