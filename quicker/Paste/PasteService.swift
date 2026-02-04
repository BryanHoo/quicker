import Foundation

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
        // 真实实现放下一步：这里先留空，让单测先跑通
    }
}

