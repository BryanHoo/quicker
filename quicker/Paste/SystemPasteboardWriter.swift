import AppKit

protocol PasteboardWriting {
    func writeString(_ string: String)
}

struct SystemPasteboardWriter: PasteboardWriting {
    func writeString(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}

