import ApplicationServices
import Foundation

protocol AccessibilityPermissionChecking {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool
}

protocol AccessibilityPermissionTrustHistoryStoring {
    var hasEverBeenTrusted: Bool { get }
    func markTrusted()
}

final class InMemoryAccessibilityPermissionTrustHistoryStore: AccessibilityPermissionTrustHistoryStoring {
    private(set) var hasEverBeenTrusted: Bool

    init(hasEverBeenTrusted: Bool = false) {
        self.hasEverBeenTrusted = hasEverBeenTrusted
    }

    func markTrusted() {
        hasEverBeenTrusted = true
    }
}

final class UserDefaultsAccessibilityPermissionTrustHistoryStore: AccessibilityPermissionTrustHistoryStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "AccessibilityPermissionHasEverBeenTrusted"
    ) {
        self.defaults = defaults
        self.key = key
    }

    var hasEverBeenTrusted: Bool {
        defaults.bool(forKey: key)
    }

    func markTrusted() {
        guard hasEverBeenTrusted == false else { return }
        defaults.set(true, forKey: key)
    }
}

struct SystemAccessibilityPermission: AccessibilityPermissionChecking {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
