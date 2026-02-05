import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: CenteredPanel?
    private let viewModel: ClipboardPanelViewModel
    private let onPaste: (ClipboardPanelEntry, NSRunningApplication?) -> Void
    private var previousFrontmostApp: NSRunningApplication?

    init(viewModel: ClipboardPanelViewModel, onPaste: @escaping (ClipboardPanelEntry, NSRunningApplication?) -> Void) {
        self.viewModel = viewModel
        self.onPaste = onPaste
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }

        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        center(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makePanel() -> CenteredPanel {
        let size = QuickerTheme.ClipboardPanel.size

        let content = ClipboardPanelView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.close()
            },
            onPaste: { [weak self] entry in
                guard let self else { return }
                self.close()
                self.onPaste(entry, self.previousFrontmostApp)
            }
        )

        let hosting = NSHostingController(rootView: content)
        let panel = CenteredPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentViewController = hosting
        return panel
    }

    private func preferredScreen() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    private func center(_ panel: NSWindow) {
        guard let screen = preferredScreen() else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = CGPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
