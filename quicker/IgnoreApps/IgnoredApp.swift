import Foundation

struct IgnoredApp: Codable, Equatable {
    let bundleIdentifier: String
    var displayName: String?
    var appPath: String?
}

