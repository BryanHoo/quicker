import Foundation

enum PreferencesKeys {
    enum maxHistoryCount {
        static let key = "maxHistoryCount"
        static let defaultValue = 200
    }

    enum dedupeAdjacentEnabled {
        static let key = "dedupeAdjacentEnabled"
        static let defaultValue = true
    }

    enum hotkey {
        static let key = "hotkey"
        static let defaultValue = Hotkey.default
    }

    enum textBlockHotkey {
        static let key = "textBlockHotkey"
        static let defaultValue = Hotkey.textBlockDefault
    }
}
