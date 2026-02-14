import AppKit
import SwiftUI

struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfiguratorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ConfiguratorView)?.applyStyleIfPossible()
    }
}

private final class ConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyStyleIfPossible()
        DispatchQueue.main.async { [weak self] in
            self?.applyStyleIfPossible()
        }
    }

    fileprivate func applyStyleIfPossible() {
        guard let window else { return }
        SettingsWindowStyle.apply(to: window)
    }
}
