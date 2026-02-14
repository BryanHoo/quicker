import SwiftUI

@main
struct QuickerApp: App {
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        DispatchQueue.main.async { state.start() }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarExtraContent(appState: appState)
        } label: {
            Image(systemName: "bolt.fill")
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel("Quicker")
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        .windowStyle(.hiddenTitleBar)
    }
}

private struct MenuBarExtraContent: View {
    let appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("打开剪贴板面板") {
            appState.togglePanel()
        }
        Button("打开文本块面板") {
            appState.toggleTextBlockPanel()
        }
        Button("偏好设置…") {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
        }
        Divider()
        Button("清空历史") {
            appState.confirmAndClearHistory()
        }
        Divider()
        Button("退出") { NSApp.terminate(nil) }
    }
}
