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
            Button("Open Clipboard Panel") {
                appState.togglePanel()
            }
            Button("Open Text Block Panel") {
                appState.toggleTextBlockPanel()
            }
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Clear History") {
                appState.confirmAndClearHistory()
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
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
