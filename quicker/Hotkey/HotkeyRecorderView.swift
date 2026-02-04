import AppKit
import SwiftUI

struct HotkeyRecorderView: NSViewRepresentable {
    var onCapture: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = RecorderView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class RecorderView: NSView {
    var onCapture: ((NSEvent) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onCapture?(event)
    }
}

