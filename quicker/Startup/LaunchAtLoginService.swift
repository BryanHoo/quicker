import Combine
import OSLog
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled: Bool = false

    private let logger = Logger(subsystem: "quicker", category: "LaunchAtLogin")

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            logger.error("Failed to set launch at login: \(String(describing: error), privacy: .public)")
        }

        refresh()
    }
}
