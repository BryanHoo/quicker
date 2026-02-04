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
        MenuBarExtra("Quicker") {
            Button("Open Clipboard Panel") {
                appState.togglePanel()
            }
            Button("Settings…") {
                appState.panelController.close()
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            Divider()
            Button("Clear History") {
                appState.confirmAndClearHistory()
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    appState.panelController.close()
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }
    }
}
