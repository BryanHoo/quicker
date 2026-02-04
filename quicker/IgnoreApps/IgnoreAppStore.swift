import Foundation

final class IgnoreAppStore {
    private let userDefaults: UserDefaults
    private let key = "ignoredApps"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func all() -> [IgnoredApp] {
        guard let data = userDefaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([IgnoredApp].self, from: data)) ?? []
    }

    func isIgnored(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return all().contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func add(bundleIdentifier: String, displayName: String?, appPath: String?) throws {
        var apps = all()
        apps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        apps.append(IgnoredApp(bundleIdentifier: bundleIdentifier, displayName: displayName, appPath: appPath))
        try save(apps)
    }

    func remove(bundleIdentifier: String) {
        var apps = all()
        apps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        try? save(apps)
    }

    private func save(_ apps: [IgnoredApp]) throws {
        let data = try JSONEncoder().encode(apps)
        userDefaults.set(data, forKey: key)
    }
}

