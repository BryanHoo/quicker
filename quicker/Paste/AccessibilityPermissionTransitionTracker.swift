import AppKit
import Foundation

enum AccessibilityPermissionDecision: Equatable {
    case paste
    case copyOnly
    case restartRequired
}

protocol AccessibilityPermissionTransitionTracking {
    func decision(for isTrusted: Bool) -> AccessibilityPermissionDecision
}

final class AccessibilityPermissionTransitionTracker: AccessibilityPermissionTransitionTracking {
    private var hasObservedUntrusted = false
    private var hasRequestedRestartAfterGrant = false

    func decision(for isTrusted: Bool) -> AccessibilityPermissionDecision {
        if isTrusted {
            guard hasObservedUntrusted, hasRequestedRestartAfterGrant == false else { return .paste }
            hasRequestedRestartAfterGrant = true
            return .restartRequired
        }

        hasObservedUntrusted = true
        hasRequestedRestartAfterGrant = false
        return .copyOnly
    }
}

protocol AccessibilityPermissionRelaunchCoordinating {
    func promptForRelaunchAfterPermissionGrant()
}

final class SystemAccessibilityPermissionRelaunchCoordinator: AccessibilityPermissionRelaunchCoordinating {
    private let relauncher: AppRelaunching

    init(relauncher: AppRelaunching = SystemAppRelauncher()) {
        self.relauncher = relauncher
    }

    func promptForRelaunchAfterPermissionGrant() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "辅助功能权限已更新"
        alert.informativeText = "为确保自动粘贴稳定生效，建议立即重启 Quicker。"
        alert.addButton(withTitle: "立即重启")
        alert.addButton(withTitle: "稍后")

        if alert.runModal() == .alertFirstButtonReturn {
            relauncher.relaunch()
        }
    }
}

protocol AppRelaunching {
    func relaunch()
}

protocol AppRelaunchProcessLaunching {
    func launchNewInstance(bundlePath: String) -> Bool
}

protocol ApplicationTerminating {
    func terminate()
}

struct OpenCommandRelaunchProcessLauncher: AppRelaunchProcessLaunching {
    func launchNewInstance(bundlePath: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", bundlePath]

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}

struct NSApplicationTerminator: ApplicationTerminating {
    func terminate() {
        NSApp.terminate(nil)
    }
}

struct SystemAppRelauncher: AppRelaunching {
    private let launcher: AppRelaunchProcessLaunching
    private let terminator: ApplicationTerminating
    private let bundlePath: String

    init(
        launcher: AppRelaunchProcessLaunching = OpenCommandRelaunchProcessLauncher(),
        terminator: ApplicationTerminating = NSApplicationTerminator(),
        bundlePath: String = Bundle.main.bundlePath
    ) {
        self.launcher = launcher
        self.terminator = terminator
        self.bundlePath = bundlePath
    }

    func relaunch() {
        guard launcher.launchNewInstance(bundlePath: bundlePath) else { return }
        terminator.terminate()
    }
}
