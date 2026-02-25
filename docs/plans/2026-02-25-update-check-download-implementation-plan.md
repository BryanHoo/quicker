# Update Check & Download Implementation Plan

> **For AI:** REQUIRED SUB-SKILL: Use workflow-executing-plans to implement this plan task-by-task.

**Goal:** 每次启动后延迟约 10 秒检查 GitHub Releases 最新版本；发现新版本时弹窗询问；用户确认后下载对应 `.dmg`（可选校验同名 `.sha256`）到本机并自动打开 DMG（不自动替换安装）。

**Architecture:** 在 `AppState.start()` 启动后触发 `AppUpdateManager`（主线程负责 UI），由 `GitHubReleaseClient` 拉取 `/releases/latest` 并解析版本；如需下载则交给 `UpdateDownloader`（后台任务做下载/校验/落盘），最终用 `NSWorkspace.shared.open` 打开 `.dmg`。

**Tech Stack:** Swift、Swift Concurrency（`Task`/`async`/`await`）、`URLSession`、`Codable`、`CryptoKit`、`OSLog`、AppKit（`NSAlert`、`NSWorkspace`）、XCTest、`xcodebuildmcp`

---

## Inputs（写计划时的上下文冻结）

### Prior Art Scan

- `docs/solutions/` 未发现与“更新检查/下载”直接相关的文档。

### Codebase Entry Points

- 启动入口：`quicker/quickerApp.swift` 在 `init()` 中 `DispatchQueue.main.async { state.start() }`
- 启动逻辑：`quicker/App/AppState.swift:290` 的 `func start()`
- 现有提示能力：`quicker/UI/ToastPresenter.swift`
- 现有 sha256 计算：`quicker/Clipboard/ContentHash.swift`（对 `Data` 计算；本需求更适合对文件流式计算）

### Verify Commands（已有）

- 全量测试：`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker`
- 单测（示例）：`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/ClipboardStoreTests"`

### Key Risks / Pitfalls

- GitHub API 可能 403 rate limit；需要优雅降级（不弹窗或仅提供打开 Release）。
- `tag_name` 可能是 `v1.2.3` 或非严格语义版本；解析失败要可控。
- `.dmg` 文件体积可能较大；校验 sha256 需要避免一次性读入内存（用流式 hash）。
- 菜单栏应用弹窗可能被压到后台；弹窗前需要 `NSApp.activate(ignoringOtherApps: true)`。
- 下载目录权限：避免写入 Downloads，使用 `Application Support/quicker/Updates/`。

---

## Task 1: Add `SemanticVersion`（解析/比较版本）+ 单测

**Files:**

- Create: `quicker/Update/SemanticVersion.swift`
- Test: `quickerTests/SemanticVersionTests.swift`

**Step 1: Write the failing test**

`quickerTests/SemanticVersionTests.swift`

```swift
import XCTest
@testable import quicker

final class SemanticVersionTests: XCTestCase {
    func testParseThreePart() {
        XCTAssertEqual(SemanticVersion("1.0.9"), SemanticVersion(major: 1, minor: 0, patch: 9))
    }

    func testParseWithLeadingV() {
        XCTAssertEqual(SemanticVersion("v2.1.0"), SemanticVersion(major: 2, minor: 1, patch: 0))
    }

    func testCompare() {
        XCTAssertTrue(SemanticVersion("1.0.10")! > SemanticVersion("1.0.9")!)
    }

    func testInvalidReturnsNil() {
        XCTAssertNil(SemanticVersion("1.0"))
        XCTAssertNil(SemanticVersion("abc"))
        XCTAssertNil(SemanticVersion("1.0.x"))
    }
}
```

**Step 2: Run test to verify it fails**

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/SemanticVersionTests"`

Expected: 编译失败（`Cannot find 'SemanticVersion' in scope`）。

**Step 3: Write minimal implementation**

`quicker/Update/SemanticVersion.swift`

```swift
import Foundation

struct SemanticVersion: Equatable, Comparable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ string: String) {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.hasPrefix("v") ? String(trimmed.dropFirst()) : trimmed
        let parts = normalized.split(separator: ".")
        guard parts.count == 3 else { return nil }
        guard
            let major = Int(parts[0]),
            let minor = Int(parts[1]),
            let patch = Int(parts[2])
        else { return nil }
        self.init(major: major, minor: minor, patch: patch)
    }
}
```

**Step 4: Run test to verify it passes**

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/SemanticVersionTests"`

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Update/SemanticVersion.swift quickerTests/SemanticVersionTests.swift
git commit -m "feat(update): 添加语义版本解析比较"
```

---

## Task 2: Add GitHub Release 模型 + 资产选择器 + `.sha256` 解析 + 单测

**Files:**

- Create: `quicker/Update/GitHubRelease.swift`
- Create: `quicker/Update/UpdateAssetPicker.swift`
- Create: `quicker/Update/SHA256Checksum.swift`
- Test: `quickerTests/UpdateAssetPickerTests.swift`
- Test: `quickerTests/SHA256ChecksumTests.swift`

**Step 1: Write the failing tests**

`quickerTests/UpdateAssetPickerTests.swift`

```swift
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
```

`quickerTests/SHA256ChecksumTests.swift`

```swift
import XCTest
@testable import quicker

final class SHA256ChecksumTests: XCTestCase {
    func testParseShasumOutput() {
        let text = "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd  quicker-v1.0.10.dmg\n"
        XCTAssertEqual(SHA256Checksum.parse(from: text)?.hashHex, "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd")
    }

    func testParseRejectsInvalid() {
        XCTAssertNil(SHA256Checksum.parse(from: "not-a-hash  file.dmg\n"))
    }
}
```

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/UpdateAssetPickerTests" --extra-args "-only-testing:quickerTests/SHA256ChecksumTests"`

Expected: 编译失败（缺少 `GitHubRelease` / `UpdateAssetPicker` / `SHA256Checksum`）。

**Step 2: Implement models + helpers**

`quicker/Update/GitHubRelease.swift`

```swift
import Foundation

struct GitHubRelease: Decodable {
    struct Asset: Decodable, Equatable {
        let name: String
        let browserDownloadURL: URL
        let size: Int

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
            case size
        }
    }

    let tagName: String
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}
```

`quicker/Update/UpdateAssetPicker.swift`

```swift
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
```

`quicker/Update/SHA256Checksum.swift`

```swift
import Foundation

struct SHA256Checksum: Equatable {
    let hashHex: String

    static func parse(from text: String) -> SHA256Checksum? {
        let token = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).first
        guard let token else { return nil }
        let hash = token.lowercased()
        guard hash.count == 64 else { return nil }
        guard hash.allSatisfy({ $0.isHexDigit }) else { return nil }
        return SHA256Checksum(hashHex: hash)
    }
}
```

**Step 3: Run tests to verify they pass**

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/UpdateAssetPickerTests" --extra-args "-only-testing:quickerTests/SHA256ChecksumTests"`

Expected: PASS

**Step 4: Commit**

```bash
git add quicker/Update/GitHubRelease.swift quicker/Update/UpdateAssetPicker.swift quicker/Update/SHA256Checksum.swift quickerTests/UpdateAssetPickerTests.swift quickerTests/SHA256ChecksumTests.swift
git commit -m "feat(update): 添加 release 解析与资产选择"
```

---

## Task 3: Add `GitHubReleaseClient`（拉取 `/releases/latest`）+（可选）网络桩单测

**Files:**

- Create: `quicker/Update/GitHubReleaseClient.swift`
- (Optional) Test: `quickerTests/GitHubReleaseClientTests.swift`

**Step 1: Implement client（先不写测试也可以，但建议至少手动验证一次）**

`quicker/Update/GitHubReleaseClient.swift`

```swift
import Foundation

enum GitHubReleaseClientError: Error {
    case invalidResponse
    case httpStatus(Int, Data)
}

struct GitHubReleaseClient {
    var session: URLSession = .shared
    var owner: String = "BryanHoo"
    var repo: String = "quicker"

    func fetchLatestRelease() async throws -> GitHubRelease {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("quicker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GitHubReleaseClientError.invalidResponse }
        guard (200...299).contains(http.statusCode) else { throw GitHubReleaseClientError.httpStatus(http.statusCode, data) }
        return try JSONDecoder().decode(GitHubRelease.self, from: data)
    }
}
```

**Step 2: (Optional) Add URLProtocol stub test**

- 在测试里创建 `URLSessionConfiguration.ephemeral`，设置 `protocolClasses = [MockURLProtocol.self]`；
- Mock 200 JSON 与 403 文本，断言 `fetchLatestRelease()` 成功/抛错。

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/GitHubReleaseClientTests"`

**Step 3: Commit**

```bash
git add quicker/Update/GitHubReleaseClient.swift quickerTests/GitHubReleaseClientTests.swift
git commit -m "feat(update): 添加 GitHub release 拉取"
```

如果选择不写该测试，则从 `git add` 中移除 `quickerTests/GitHubReleaseClientTests.swift`。

---

## Task 4: Add 文件 sha256（流式）+ `UpdateDownloader`（下载/校验/落盘）

**Files:**

- Create: `quicker/Update/FileSHA256.swift`
- Create: `quicker/Update/UpdateDownloader.swift`
- Test: `quickerTests/FileSHA256Tests.swift`

**Step 1: Write failing test（用临时文件验证流式 hash）**

`quickerTests/FileSHA256Tests.swift`

```swift
import Foundation
import XCTest
@testable import quicker

final class FileSHA256Tests: XCTestCase {
    func testSHA256HexForFile() throws {
        let dir = FileManager.default.temporaryDirectory
        let url = dir.appendingPathComponent(UUID().uuidString)
        try Data("A".utf8).write(to: url, options: .atomic)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertEqual(
            try FileSHA256.sha256Hex(fileURL: url),
            "559aead08264d5795d3909718cdd05abd49572e84fe55590eef31a88a08fdffd"
        )
    }
}
```

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/FileSHA256Tests"`

Expected: 编译失败（缺少 `FileSHA256`）。

**Step 2: Implement stream hasher**

`quicker/Update/FileSHA256.swift`

```swift
import CryptoKit
import Foundation

enum FileSHA256 {
    static func sha256Hex(fileURL: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }

        var hasher = SHA256()
        while true {
            let chunk = try handle.read(upToCount: 1024 * 1024) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
```

**Step 3: Implement downloader**

`quicker/Update/UpdateDownloader.swift`

```swift
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
```

**Step 4: Run tests**

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/FileSHA256Tests"`

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Update/FileSHA256.swift quicker/Update/UpdateDownloader.swift quickerTests/FileSHA256Tests.swift
git commit -m "feat(update): 添加更新下载与校验"
```

---

## Task 5: Add `AppUpdateManager`（检查+弹窗+触发下载）并接入 `AppState.start()`

**Files:**

- Create: `quicker/Update/AppUpdateManager.swift`
- Modify: `quicker/App/AppState.swift:290`

**Step 1: Implement manager**

`quicker/Update/AppUpdateManager.swift`

```swift
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
            Task.detached { [downloader, toast] in
                do {
                    let dmg = UpdateAssetPicker.pickDMG(from: release.assets)
                    guard let dmg else { throw UpdateDownloaderError.missingDMGAsset }
                    let sha = UpdateAssetPicker.pickSHA256(for: dmg, in: release.assets)
                    let fileURL = try await downloader.downloadDMG(dmg: dmg, sha256: sha)
                    await MainActor.run {
                        toast.show(message: "下载完成，正在打开…", duration: 1.6)
                        NSWorkspace.shared.open(fileURL)
                    }
                } catch {
                    await MainActor.run {
                        toast.show(message: "下载失败：\(String(describing: error))", duration: 2.4)
                        NSWorkspace.shared.open(release.htmlURL)
                    }
                }
            }
        case .alertThirdButtonReturn:
            NSWorkspace.shared.open(release.htmlURL)
        default:
            break
        }
    }
}
```

**Step 2: Wire into `AppState.start()`**

在 `quicker/App/AppState.swift` 增加一个属性（例如 `private let appUpdateManager: AppUpdateManager`），在 `init()` 创建，并在 `start()`（`quicker/App/AppState.swift:290`）末尾调用：

```swift
appUpdateManager.scheduleCheckAfterLaunch()
```

**Step 3: Build & smoke test**

Run:

`xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug`

Expected: Build success

手动验证（需要真实存在一个更高版本的 GitHub Release，且包含 `.dmg` 资产）：
- 启动 app 后约 10 秒出现更新弹窗
- 点击 `下载并打开 DMG` 后下载并自动打开 `.dmg`

**Step 4: Commit**

```bash
git add quicker/Update/AppUpdateManager.swift quicker/App/AppState.swift
git commit -m "feat(update): 启动后提示并下载更新"
```

---

## Task 6: 回归测试

Run:

`xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker`

Expected: PASS

如果出现偶发 UI/权限相关失败，优先只跑逻辑单测 target（`quickerTests`）并记录失败用例再处理。

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-25-update-check-download-implementation-plan.md`.

Two execution options:

1. Sequential (this session) — 逐个 Task 执行并在每个 Task 完成后做一次快速确认
2. Sequential (separate session) — 新开 session，使用 `workflow-executing-plans` 串行执行

Which approach?

