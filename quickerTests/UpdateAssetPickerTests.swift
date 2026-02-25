import XCTest
@testable import quicker

final class UpdateAssetPickerTests: XCTestCase {
    func testPickDMGPrefersQuickerPrefix() {
        let assets: [GitHubRelease.Asset] = [
            .init(name: "other-1.dmg", browserDownloadURL: URL(string: "https://example.com/other")!, size: 10),
            .init(name: "quicker-v1.0.10.dmg", browserDownloadURL: URL(string: "https://example.com/quicker")!, size: 9),
        ]
        XCTAssertEqual(UpdateAssetPicker.pickDMG(from: assets)?.name, "quicker-v1.0.10.dmg")
    }

    func testPickSHA256MatchesDMGName() {
        let dmg = GitHubRelease.Asset(name: "quicker-v1.0.10.dmg", browserDownloadURL: URL(string: "https://example.com/quicker")!, size: 9)
        let assets: [GitHubRelease.Asset] = [
            dmg,
            .init(name: "quicker-v1.0.10.dmg.sha256", browserDownloadURL: URL(string: "https://example.com/sha")!, size: 1),
        ]
        XCTAssertEqual(UpdateAssetPicker.pickSHA256(for: dmg, in: assets)?.name, "quicker-v1.0.10.dmg.sha256")
    }
}
