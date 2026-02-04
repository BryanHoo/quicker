import AppKit
import UniformTypeIdentifiers

enum OpenPanelAppPicker {
    static func pickAppUrl() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle] // 仅 .app
        return panel.runModal() == .OK ? panel.url : nil
    }
}

