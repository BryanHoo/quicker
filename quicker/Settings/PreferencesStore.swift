import Foundation

final class PreferencesStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var maxHistoryCount: Int {
        get {
            guard userDefaults.object(forKey: PreferencesKeys.maxHistoryCount.key) != nil else {
                return PreferencesKeys.maxHistoryCount.defaultValue
            }
            return userDefaults.integer(forKey: PreferencesKeys.maxHistoryCount.key)
        }
        set { userDefaults.set(newValue, forKey: PreferencesKeys.maxHistoryCount.key) }
    }

    var dedupeAdjacentEnabled: Bool {
        get {
            guard userDefaults.object(forKey: PreferencesKeys.dedupeAdjacentEnabled.key) != nil else {
                return PreferencesKeys.dedupeAdjacentEnabled.defaultValue
            }
            return userDefaults.bool(forKey: PreferencesKeys.dedupeAdjacentEnabled.key)
        }
        set { userDefaults.set(newValue, forKey: PreferencesKeys.dedupeAdjacentEnabled.key) }
    }

    var hotkey: Hotkey {
        get {
            guard
                let data = userDefaults.data(forKey: PreferencesKeys.hotkey.key),
                let value = try? JSONDecoder().decode(Hotkey.self, from: data)
            else {
                return PreferencesKeys.hotkey.defaultValue
            }
            return value
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaults.set(data, forKey: PreferencesKeys.hotkey.key)
        }
    }

    var textBlockHotkey: Hotkey {
        get {
            guard
                let data = userDefaults.data(forKey: PreferencesKeys.textBlockHotkey.key),
                let value = try? JSONDecoder().decode(Hotkey.self, from: data)
            else {
                return PreferencesKeys.textBlockHotkey.defaultValue
            }
            return value
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaults.set(data, forKey: PreferencesKeys.textBlockHotkey.key)
        }
    }
}
