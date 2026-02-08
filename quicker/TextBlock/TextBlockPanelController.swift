import AppKit
import SwiftUI

@MainActor
final class TextBlockPanelController: NSObject, NSWindowDelegate {
    private var panel: CenteredPanel?
    private let viewModel: TextBlockPanelViewModel
    private let onInsert: (TextBlockPanelEntry, RunningApplicationActivating?) -> Void
    private var previousFrontmostApp: RunningApplicationActivating?

    init(
        viewModel: TextBlockPanelViewModel,
        onInsert: @escaping (TextBlockPanelEntry, RunningApplicationActivating?) -> Void
    ) {
        self.viewModel = viewModel
        self.onInsert = onInsert
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        let isFirstPresentation = (panel == nil)
        if panel == nil { panel = makePanel() }
        guard let panel else { return }

        previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        NSApp.activate(ignoringOtherApps: true)

        let screen = preferredScreen()
        center(panel, on: screen)

        if isFirstPresentation {
            panel.alphaValue = 0
        } else {
            panel.alphaValue = 1
        }

        panel.makeKeyAndOrderFront(nil)

        if isFirstPresentation {
            DispatchQueue.main.async { [weak self] in
                guard let self, let panel = self.panel, panel.isVisible else { return }
                panel.contentView?.layoutSubtreeIfNeeded()
                self.center(panel, on: screen)
                panel.alphaValue = 1
            }
        }
    }

    func close() {
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makePanel() -> CenteredPanel {
        let size = QuickerTheme.ClipboardPanel.size
        let content = TextBlockPanelView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.close() },
            onInsert: { [weak self] entry in
                guard let self else { return }
                self.close()
                self.onInsert(entry, self.previousFrontmostApp)
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
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func center(_ panel: NSWindow) {
        center(panel, on: preferredScreen())
    }

    private func center(_ panel: NSWindow, on screen: NSScreen?) {
        guard let screen else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
    }
}
