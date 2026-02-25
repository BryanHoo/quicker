import Foundation

enum UpdateAssetPicker {
    static func pickDMG(from assets: [GitHubRelease.Asset]) -> GitHubRelease.Asset? {
        let dmgs = assets.filter { $0.name.lowercased().hasSuffix(".dmg") }
        guard !dmgs.isEmpty else { return nil }
        if let preferred = dmgs.first(where: { $0.name.hasPrefix("quicker-") }) { return preferred }
        return dmgs.max(by: { $0.size < $1.size })
    }

    static func pickSHA256(for dmg: GitHubRelease.Asset, in assets: [GitHubRelease.Asset]) -> GitHubRelease.Asset? {
        let shaName = dmg.name + ".sha256"
        return assets.first(where: { $0.name == shaName })
    }
}
