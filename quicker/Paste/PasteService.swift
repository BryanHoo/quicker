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
    private let assetStore: ClipboardAssetStoring

    init(
        writer: PasteboardWriting = SystemPasteboardWriter(),
        eventSender: PasteEventSending = SystemPasteEventSender(),
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission(),
        assetStore: ClipboardAssetStoring = ClipboardAssetStore()
    ) {
        self.writer = writer
        self.eventSender = eventSender
        self.permission = permission
        self.assetStore = assetStore
    }

    func paste(text: String, skipCapture: Bool = false) -> PasteResult {
        writer.writeString(text, skipCapture: skipCapture)
        return maybeSendCmdV()
    }

    func paste(entry: ClipboardEntry, skipCapture: Bool = false) -> PasteResult {
        switch ClipboardEntryKind(raw: entry.kindRaw) {
        case .text:
            return paste(text: entry.text, skipCapture: skipCapture)
        case .rtf:
            if let rtf = entry.rtfData {
                writer.writeRTF(rtf, plainText: entry.text, skipCapture: skipCapture)
                return maybeSendCmdV()
            }
            return paste(text: entry.text, skipCapture: skipCapture)
        case .image:
            guard let path = entry.imagePath, let png = try? assetStore.loadImageData(relativePath: path) else {
                writer.writeString(entry.text, skipCapture: skipCapture)
                return .copiedOnly
            }
            writer.writePNG(png, skipCapture: skipCapture)
            return maybeSendCmdV()
        }
    }

    private func maybeSendCmdV() -> PasteResult {
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
