import Foundation

protocol ClipboardAssetStoring {
    func saveImage(pngData: Data, contentHash: String) throws -> String
    func loadImageData(relativePath: String) throws -> Data
    func deleteImage(relativePath: String) throws
    func fileURL(relativePath: String) -> URL
}

struct ClipboardAssetStore: ClipboardAssetStoring {
    private let baseURL: URL

    init(baseURL: URL = ClipboardAssetStore.defaultBaseURL()) {
        self.baseURL = baseURL
    }

    static func defaultBaseURL() -> URL {
        let fm = FileManager.default
        let appSupport = try! fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let bundleId = Bundle.main.bundleIdentifier ?? "quicker"
        return appSupport
            .appendingPathComponent(bundleId, isDirectory: true)
            .appendingPathComponent("clipboard-assets", isDirectory: true)
    }

    private func ensureBaseDir() throws {
        try FileManager.default.createDirectory(
            at: baseURL,
            withIntermediateDirectories: true
        )
    }

    func fileURL(relativePath: String) -> URL {
        baseURL.appendingPathComponent(relativePath, isDirectory: false)
    }

    func saveImage(pngData: Data, contentHash: String) throws -> String {
        try ensureBaseDir()
        let rel = "\(contentHash).png"
        try pngData.write(to: fileURL(relativePath: rel), options: .atomic)
        return rel
    }

    func loadImageData(relativePath: String) throws -> Data {
        try Data(contentsOf: fileURL(relativePath: relativePath))
    }

    func deleteImage(relativePath: String) throws {
        let url = fileURL(relativePath: relativePath)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }
}

