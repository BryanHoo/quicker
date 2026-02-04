import ApplicationServices

protocol AccessibilityPermissionChecking {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool
}

struct SystemAccessibilityPermission: AccessibilityPermissionChecking {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}

