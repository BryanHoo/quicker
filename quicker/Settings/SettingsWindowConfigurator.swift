import AppKit
import SwiftUI

struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfiguratorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        SettingsWindowStyle.apply(to: window)
    }
}
