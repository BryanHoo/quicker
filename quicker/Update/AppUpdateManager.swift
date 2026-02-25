import AppKit
import OSLog

@MainActor
final class AppUpdateManager {
    private let logger = Logger(subsystem: "quicker", category: "Update")

    private let toast: ToastPresenter
    private let releaseClient: GitHubReleaseClient
    private let downloader: UpdateDownloader

    private var didCheckThisLaunch = false

    init(
        toast: ToastPresenter,
        releaseClient: GitHubReleaseClient = .init(),
        downloader: UpdateDownloader = .init()
    ) {
        self.toast = toast
        self.releaseClient = releaseClient
        self.downloader = downloader
    }

    func scheduleCheckAfterLaunch(delaySeconds: Double = 10) {
        guard !didCheckThisLaunch else { return }
        didCheckThisLaunch = true
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
            await self?.checkAndPromptIfNeeded()
        }
    }

    func checkAndPromptIfNeeded() async {
        guard let currentString = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let current = SemanticVersion(currentString)
        else {
            logger.error("Cannot read/parse CFBundleShortVersionString")
            return
        }

        let release: GitHubRelease
        do {
            release = try await releaseClient.fetchLatestRelease()
        } catch {
            logger.error("fetchLatestRelease failed: \(String(describing: error), privacy: .public)")
            return
        }

        guard let remote = SemanticVersion(release.tagName) else {
            logger.error("Cannot parse release.tagName=\(release.tagName, privacy: .public)")
            return
        }

        guard remote > current else { return }

        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "发现新版本 \(release.tagName)"
        alert.informativeText = "当前版本 \(currentString)。是否下载更新？下载完成后会自动打开 DMG，需要手动拖拽覆盖安装。"
        alert.addButton(withTitle: "下载并打开 DMG")
        alert.addButton(withTitle: "稍后")
        alert.addButton(withTitle: "查看 Release")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            toast.show(message: "开始下载更新…", duration: 1.2)

            let releaseURL = release.htmlURL
            guard let dmg = UpdateAssetPicker.pickDMG(from: release.assets) else {
                toast.show(message: "未找到 DMG 资产，已打开 Release。", duration: 2.4)
                NSWorkspace.shared.open(releaseURL)
                return
            }
            let sha = UpdateAssetPicker.pickSHA256(for: dmg, in: release.assets)

            let dmgName = dmg.name
            let dmgURL = dmg.browserDownloadURL
            let dmgSize = dmg.size
            let shaName = sha?.name
            let shaURL = sha?.browserDownloadURL
            let shaSize = sha?.size

            Task {
                do {
                    let fileURL = try await Task.detached(priority: .utility) {
                        let dmgAsset = GitHubRelease.Asset(name: dmgName, browserDownloadURL: dmgURL, size: dmgSize)
                        let shaAsset = (shaName != nil && shaURL != nil && shaSize != nil)
                            ? GitHubRelease.Asset(name: shaName!, browserDownloadURL: shaURL!, size: shaSize!)
                            : nil
                        let downloader = UpdateDownloader()
                        return try await downloader.downloadDMG(dmg: dmgAsset, sha256: shaAsset)
                    }.value

                    toast.show(message: "下载完成，正在打开…", duration: 1.6)
                    NSWorkspace.shared.open(fileURL)
                } catch {
                    toast.show(message: "下载失败：\(String(describing: error))", duration: 2.4)
                    NSWorkspace.shared.open(releaseURL)
                }
            }
        case .alertThirdButtonReturn:
            NSWorkspace.shared.open(release.htmlURL)
        default:
            break
        }
    }
}
