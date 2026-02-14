import AppKit

enum SettingsWindowStyle {
    static func apply(to window: NSWindow) {
        window.title = ""
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)
        window.styleMask.remove(.unifiedTitleAndToolbar)

        window.isOpaque = false
        window.backgroundColor = .clear

        window.toolbar = nil

        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = false

        window.isMovableByWindowBackground = true
    }
}
