import Carbon
import Foundation

struct Hotkey: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = Hotkey(
        keyCode: 9, // v
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let textBlockDefault = Hotkey(
        keyCode: 11, // b
        modifiers: UInt32(cmdKey | shiftKey)
    )
}

extension Hotkey {
    var displayString: String {
        let modifiersString = HotkeyDisplay.modifiersString(modifiers)
        let keyString = HotkeyDisplay.keyString(keyCode)
        return modifiersString + keyString
    }
}

private enum HotkeyDisplay {
    static func modifiersString(_ modifiers: UInt32) -> String {
        var result = ""
        if modifiers & UInt32(cmdKey) != 0 { result += "⌘" }
        if modifiers & UInt32(shiftKey) != 0 { result += "⇧" }
        if modifiers & UInt32(optionKey) != 0 { result += "⌥" }
        if modifiers & UInt32(controlKey) != 0 { result += "⌃" }
        return result
    }

    static func keyString(_ keyCode: UInt32) -> String {
        if let special = specialKeyString(keyCode) {
            return special
        }

        if let translated = translateKeyCode(keyCode) {
            let trimmed = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty == false {
                return trimmed.uppercased()
            }
        }

        return "键码 \(keyCode)"
    }

    private static func specialKeyString(_ keyCode: UInt32) -> String? {
        switch keyCode {
        case 36: return "↩" // Return
        case 48: return "⇥" // Tab
        case 49: return "␣" // Space
        case 51: return "⌫" // Delete
        case 53: return "⎋" // Escape
        case 117: return "⌦" // Forward Delete
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return nil
        }
    }

    private static func translateKeyCode(_ keyCode: UInt32) -> String? {
        let inputSource = TISCopyCurrentKeyboardLayoutInputSource().takeRetainedValue()
        guard let rawLayoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else { return nil }

        let layoutData = unsafeBitCast(rawLayoutData, to: CFData.self)
        guard let dataPtr = CFDataGetBytePtr(layoutData) else { return nil }
        let keyboardLayout = UnsafeRawPointer(dataPtr).assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeyState: UInt32 = 0
        let maxStringLength = 4
        var actualStringLength: Int = 0
        var unicodeString = [UniChar](repeating: 0, count: maxStringLength)

        let status = unicodeString.withUnsafeMutableBufferPointer { buffer -> OSStatus in
            guard let baseAddress = buffer.baseAddress else { return OSStatus(paramErr) }
            return UCKeyTranslate(
                keyboardLayout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                maxStringLength,
                &actualStringLength,
                baseAddress
            )
        }

        guard status == noErr else { return nil }
        return unicodeString.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return nil }
            return String(utf16CodeUnits: baseAddress, count: actualStringLength)
        }
    }
}
