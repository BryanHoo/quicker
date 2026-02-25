import Foundation

enum UpdateDownloaderError: Error {
    case missingUpdatesDirectory
    case missingDMGAsset
    case checksumMismatch
}

struct UpdateDownloader {
    var session: URLSession = .shared

    func updatesDirectory() throws -> URL {
        let fm = FileManager.default
        let base = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base
            .appendingPathComponent("quicker", isDirectory: true)
            .appendingPathComponent("Updates", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func downloadDMG(dmg: GitHubRelease.Asset, sha256: GitHubRelease.Asset?) async throws -> URL {
        let fm = FileManager.default
        let dir = try updatesDirectory()
        let dest = dir.appendingPathComponent(dmg.name, isDirectory: false)

        if fm.fileExists(atPath: dest.path),
           let attrs = try? fm.attributesOfItem(atPath: dest.path),
           let size = attrs[.size] as? NSNumber,
           size.intValue == dmg.size {
            if let sha256 {
                try await validateChecksum(fileURL: dest, sha256Asset: sha256)
            }
            return dest
        }

        if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }

        let (temp, _) = try await session.download(from: dmg.browserDownloadURL)
        try fm.moveItem(at: temp, to: dest)

        if let sha256 {
            do {
                try await validateChecksum(fileURL: dest, sha256Asset: sha256)
            } catch {
                try? fm.removeItem(at: dest)
                throw error
            }
        }

        return dest
    }

    private func validateChecksum(fileURL: URL, sha256Asset: GitHubRelease.Asset) async throws {
        let (data, _) = try await session.data(from: sha256Asset.browserDownloadURL)
        let text = String(decoding: data, as: UTF8.self)
        guard let expected = SHA256Checksum.parse(from: text)?.hashHex else { return }
        let actual = try FileSHA256.sha256Hex(fileURL: fileURL)
        guard expected == actual else { throw UpdateDownloaderError.checksumMismatch }
    }
}

