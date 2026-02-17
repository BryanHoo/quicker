import AppKit
import SwiftUI

struct PanelKeyCommandMonitor: View {
    let panelIdentifier: NSUserInterfaceItemIdentifier
    let pageSize: Int
    let onCommand: (PanelKeyCommand) -> Bool

    @State private var monitorToken: Any?

    var body: some View {
        Color.clear
            .onAppear {
                if monitorToken != nil { return }
                monitorToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard shouldHandleEvent(event) else { return event }
                    guard let cmd = interpretCommand(for: event) else { return event }
                    let handled = onCommand(cmd)
                    return handled ? nil : event
                }
            }
            .onDisappear {
                if let token = monitorToken {
                    NSEvent.removeMonitor(token)
                    monitorToken = nil
                }
            }
    }

    private func shouldHandleEvent(_ event: NSEvent) -> Bool {
        guard let window = NSApp.keyWindow, window.isVisible else { return false }
        guard window.identifier == panelIdentifier else { return false }

        // Avoid hijacking text editing shortcuts.
        if isArrowKey(event), hasMovementModifiers(event) { return false }

        // Avoid breaking IME composing (marked text) for navigation/confirm.
        if isReturnKey(event) || isArrowKey(event) {
            if hasMarkedText(in: window) { return false }
        }

        return true
    }

    private func interpretCommand(for event: NSEvent) -> PanelKeyCommand? {
        let keyEvent = PanelKeyEvent(
            keyCode: UInt16(event.keyCode),
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            isCommandDown: event.modifierFlags.contains(.command)
        )
        return PanelKeyCommand.interpret(keyEvent, pageSize: pageSize)
    }

    private func isArrowKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123, 124, 125, 126: return true
        default: return false
        }
    }

    private func isReturnKey(_ event: NSEvent) -> Bool {
        event.keyCode == 36
    }

    private func hasMovementModifiers(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command)
            || event.modifierFlags.contains(.option)
            || event.modifierFlags.contains(.shift)
            || event.modifierFlags.contains(.control)
    }

    private func hasMarkedText(in window: NSWindow) -> Bool {
        if let textView = window.firstResponder as? NSTextView {
            return textView.hasMarkedText()
        }
        return false
    }
}
