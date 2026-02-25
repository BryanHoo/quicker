import AppKit

protocol PasteboardWriting {
    func writeString(_ string: String)
    func writeRTF(_ rtf: Data, plainText: String)
    func writePNG(_ png: Data)
}

struct SystemPasteboardWriter: PasteboardWriting {
    private static let quickerInternalType = NSPasteboard.PasteboardType("com.bryanhu.quicker.internal.skipCapture")

    func writeString(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setString(string, forType: .string)
        item.setData(Data([0x01]), forType: Self.quickerInternalType)
        pb.writeObjects([item])
    }

    func writeRTF(_ rtf: Data, plainText: String) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setData(rtf, forType: .rtf)
        item.setString(plainText, forType: .string)
        item.setData(Data([0x01]), forType: Self.quickerInternalType)
        pb.writeObjects([item])
    }

    func writePNG(_ png: Data) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        item.setData(Data([0x01]), forType: Self.quickerInternalType)
        pb.writeObjects([item])
    }
}
