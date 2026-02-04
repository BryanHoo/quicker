import Foundation
import CoreGraphics

protocol PasteEventSending {
    func sendCmdV()
}

enum PasteResult: Equatable {
    case pasted
    case copiedOnly
}

final class PasteService {
    private let writer: PasteboardWriting
    private let eventSender: PasteEventSending
    private let permission: AccessibilityPermissionChecking

    init(
        writer: PasteboardWriting = SystemPasteboardWriter(),
        eventSender: PasteEventSending = SystemPasteEventSender(),
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()
    ) {
        self.writer = writer
        self.eventSender = eventSender
        self.permission = permission
    }

    func paste(text: String) -> PasteResult {
        writer.writeString(text)
        guard permission.isProcessTrusted(promptIfNeeded: false) else { return .copiedOnly }
        eventSender.sendCmdV()
        return .pasted
    }
}

struct SystemPasteEventSender: PasteEventSending {
    func sendCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
