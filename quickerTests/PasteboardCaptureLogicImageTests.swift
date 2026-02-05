import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
@testable import quicker

final class PasteboardCaptureLogicImageTests: XCTestCase {
    func testDownsamplesWhenMaxPixelExceeded() throws {
        // 生成一个 100x50 的 TIFF 数据
        let tiff = try TestImageFactory.makeTIFF(width: 100, height: 50)

        let snapshot = PasteboardSnapshot(items: [
            .init(typeIdentifiers: ["public.tiff"], pngData: nil, tiffData: tiff, rtfData: nil, string: nil),
        ])

        var logic = PasteboardCaptureLogic()
        logic.maxStoredImageMaxPixel = 40
        logic.maxStoredImageBytes = 1024 * 1024

        let captured = try XCTUnwrap(logic.capture(snapshot: snapshot))
        XCTAssertEqual(captured.kind, .image)

        let png = try XCTUnwrap(captured.pngData)
        let size = try TestImageFactory.imagePixelSize(pngData: png)
        XCTAssertLessThanOrEqual(max(size.width, size.height), 40)
    }

    func testSkipsWhenPngBytesExceedLimit() throws {
        let huge = Data(repeating: 0x01, count: 10)
        var logic = PasteboardCaptureLogic()
        logic.maxStoredImageBytes = 5
        logic.maxStoredImageMaxPixel = 4096

        let snapshot = PasteboardSnapshot(items: [
            .init(typeIdentifiers: ["public.png"], pngData: huge, tiffData: nil, rtfData: nil, string: nil),
        ])
        XCTAssertNil(logic.capture(snapshot: snapshot))
    }
}

enum TestImageFactory {
    static func makeTIFF(width: Int, height: Int) throws -> Data {
        enum Err: Error { case encodeFailed }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerRow = width * 4
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw Err.encodeFailed
        }

        ctx.setFillColor(red: 1, green: 0, blue: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let img = ctx.makeImage() else { throw Err.encodeFailed }

        let out = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(out, UTType.tiff.identifier as CFString, 1, nil) else {
            throw Err.encodeFailed
        }
        CGImageDestinationAddImage(dest, img, nil)
        guard CGImageDestinationFinalize(dest) else { throw Err.encodeFailed }
        return out as Data
    }

    static func imagePixelSize(pngData: Data) throws -> (width: Int, height: Int) {
        enum Err: Error { case decodeFailed }

        guard let src = CGImageSourceCreateWithData(pngData as CFData, nil) else { throw Err.decodeFailed }
        guard let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any] else { throw Err.decodeFailed }

        let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        guard w > 0, h > 0 else { throw Err.decodeFailed }
        return (w, h)
    }
}
