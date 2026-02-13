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
            Button("打开剪贴板面板") {
                appState.togglePanel()
            }
            Button("打开文本块面板") {
                appState.toggleTextBlockPanel()
            }
            SettingsLink {
                Text("偏好设置…")
            }
            Divider()
            Button("清空历史") {
                appState.confirmAndClearHistory()
            }
            Divider()
            Button("退出") { NSApp.terminate(nil) }
        } label: {
            Image(systemName: "bolt.fill")
                .symbolRenderingMode(.hierarchical)
                .accessibilityLabel("Quicker")
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
