import AppKit
import SwiftUI

@MainActor
final class ToastPresenter {
    private var window: NSWindow?

    func show(message: String, duration: TimeInterval = 1.2) {
        window?.orderOut(nil)

        let view = Text(message)
            .font(.system(size: 13))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hosting

        center(panel)
        panel.orderFrontRegardless()
        window = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
        }
    }

    private func center(_ window: NSWindow) {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let screen else { return }

        let frame = screen.visibleFrame
        let size = window.frame.size
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        window.setFrameOrigin(origin)
    }
}

