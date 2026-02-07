import Carbon
import Foundation

enum HotkeyValidationError: Equatable {
    case missingCommand
    case conflictsWithClipboard
    case conflictsWithTextBlock
}

enum HotkeyValidation {
    static func validateClipboard(_ hotkey: Hotkey, textBlockHotkey: Hotkey) -> HotkeyValidationError? {
        guard hotkey != textBlockHotkey else { return .conflictsWithTextBlock }
        return nil
    }

    static func validateTextBlock(_ hotkey: Hotkey, clipboardHotkey: Hotkey) -> HotkeyValidationError? {
        let hasCommand = (hotkey.modifiers & UInt32(cmdKey)) != 0
        guard hasCommand else { return .missingCommand }
        guard hotkey != clipboardHotkey else { return .conflictsWithClipboard }
        return nil
    }
}
