import AppKit

protocol PasteboardWriting {
    func writeString(_ string: String)
    func writeRTF(_ rtf: Data, plainText: String)
    func writePNG(_ png: Data)
}

struct SystemPasteboardWriter: PasteboardWriting {
    func writeString(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }

    func writeRTF(_ rtf: Data, plainText: String) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setData(rtf, forType: .rtf)
        item.setString(plainText, forType: .string)
        pb.writeObjects([item])
    }

    func writePNG(_ png: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        pb.writeObjects([item])
    }
}
