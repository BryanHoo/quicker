import AppKit

protocol PasteboardWriting {
    func writeString(_ string: String, skipCapture: Bool)
    func writeRTF(_ rtf: Data, plainText: String, skipCapture: Bool)
    func writePNG(_ png: Data, skipCapture: Bool)
}

struct SystemPasteboardWriter: PasteboardWriting {
    private static let quickerInternalType = NSPasteboard.PasteboardType("com.bryanhu.quicker.internal.skipCapture")

    func writeString(_ string: String, skipCapture: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setString(string, forType: .string)
        if skipCapture {
            item.setData(Data([0x01]), forType: Self.quickerInternalType)
        }
        pb.writeObjects([item])
    }

    func writeRTF(_ rtf: Data, plainText: String, skipCapture: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setData(rtf, forType: .rtf)
        item.setString(plainText, forType: .string)
        if skipCapture {
            item.setData(Data([0x01]), forType: Self.quickerInternalType)
        }
        pb.writeObjects([item])
    }

    func writePNG(_ png: Data, skipCapture: Bool) {
        let pb = NSPasteboard.general
        pb.clearContents()

        let item = NSPasteboardItem()
        item.setData(png, forType: .png)
        if skipCapture {
            item.setData(Data([0x01]), forType: Self.quickerInternalType)
        }
        pb.writeObjects([item])
    }
}
