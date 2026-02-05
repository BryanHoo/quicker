# Quicker（macOS）MVP Implementation Plan

> **For codex:** REQUIRED SUB-SKILL: Use superpowers-executing-plans to implement this plan task-by-task.

**Goal:** 实现一个“键盘优先”的 macOS 菜单栏剪切板历史工具：全局热键唤出居中面板，选择文本后自动粘贴（有辅助功能权限时）或降级为仅写入剪贴板，并提供基础设置（最大历史条数、相邻去重、忽略 App、清空、开机自启、快捷键配置、关于）。

**Architecture:** SwiftUI 负责 Scene（`MenuBarExtra`、`Settings`）与主要 UI；AppKit 负责 `NSPanel` 行为与焦点/失焦关闭；Carbon 负责全局热键；SwiftData 持久化剪切板历史；UserDefaults 持久化偏好项；`PasteService` 封装“写剪贴板 +（可选）模拟 ⌘V”的粘贴策略。

**Tech Stack:** SwiftUI、AppKit、SwiftData、Carbon（全局热键）、CoreGraphics（CGEvent）、ServiceManagement（`SMAppService`）、OSLog、XCTest

---

## 0. 输入与验收标准（先读这些）

**需求/设计来源：**
- `quicker-mvp-prd.md`（功能与验收口径）
- `docs/plans/2026-02-04-quicker-mvp-design.md`（已确认决策 + 架构草案 + 交互细节）

**MVP 验收清单（实现过程中随时对照）：**
- 仅记录文本剪切板；默认持久化；最大历史条数可配（默认 200）且变更后立即裁剪
- 菜单栏常驻（无 Dock 图标）；菜单含：打开面板/设置/清空/退出
- 全局热键默认 `⌘⇧V` toggle 面板；支持在设置中修改且立即生效，并给出冲突风险提示；面板居中、每页 5 条、支持 `←/→` 翻页、显示页码 `2/10`
- `↑/↓` 移动选中；默认选中最新；`Enter` 粘贴选中项并关闭；`⌘1..5` 直选粘贴本页条目并关闭
- 面板：`Esc` 关闭；点击外部/切换 App/失去焦点自动关闭（不粘贴）
- 设置：`⌘,` 打开设置；若面板打开则先关闭面板再打开设置（互斥）
- 忽略 App：通过“选择应用…”（`NSOpenPanel` 仅 `.app`）添加；命中忽略列表时不记录
- 粘贴策略：有“辅助功能/可访问性”权限时自动 `⌘V`；无权限时仅写剪贴板并提示引导

**口径补充（已确认）：**
- 无“辅助功能/可访问性”权限时：`Enter` / `⌘1..5` 仍**立即关闭面板**；并用“非阻塞”轻提示告知“已复制到剪贴板（可手动 `⌘V`）”。
- 从历史选择粘贴/复制会写入系统剪贴板，因此会被 `ClipboardMonitor` 记录为一条新历史（等价于“提升到最新”）；相邻去重仅对“连续相同内容”生效，不阻止该提升行为。
- 菜单打开面板与热键打开面板行为一致：**展示前刷新最新 entries**（避免面板内容陈旧）。

---

## 1. 一次性准备（不写业务代码）

> 目标：让后续每一步都能用统一方式稳定跑 build/test，并符合“菜单栏常驻（无 Dock 图标）”。
>
> ⚠️ 规则：任何 Xcode 相关操作（list/build/test/clean）都必须使用 **xc-all MCP** 的 `xcode_list` / `xcode_build` / `xcode_test` / `xcode_clean`；不要在 bash 里直接运行 `xcodebuild`。

1) 创建隔离分支/工作区（可选但强烈建议）

```bash
git checkout -b codex/quicker-mvp
```

2) 确认 scheme（必须先做，否则后面所有“Run test”步骤会卡住）

Invoke（xc-all MCP / `xcode_list`）:
```json
{
  "project_path": "quicker.xcodeproj"
}
```

Expected:
- 返回 `schemes` 列表，并包含 `quicker`（或你实际的 scheme 名）

若没有 scheme：
- 用 Xcode 打开 `quicker.xcodeproj`
- Product → Scheme → Manage Schemes… → 勾选 Shared（让 scheme 写入 `quicker.xcodeproj/xcshareddata/xcschemes/`）
- 重新执行上面的 `xcode_list` 直到能看到 scheme

3) 对齐部署版本到 PRD（macOS 14+）

当前 `quicker.xcodeproj/project.pbxproj` 里 `MACOSX_DEPLOYMENT_TARGET = 26.2;`（项目级 Debug/Release）。需要改到 `14.0`（或团队约定的最小版本）。

Modify:
- `quicker.xcodeproj/project.pbxproj:271-390`（项目级 `MACOSX_DEPLOYMENT_TARGET`）

4) 让 App 成为菜单栏常驻（无 Dock 图标）

因为目前 `GENERATE_INFOPLIST_FILE = YES;`，建议用 build setting 写 Info.plist key：

Modify:
- `quicker.xcodeproj/project.pbxproj:392-455`（target quicker 的 Debug/Release buildSettings）

Add:
- `INFOPLIST_KEY_LSUIElement = YES;`

5) 做一次 smoke test（只验证“能跑测试”，不追求覆盖率）

Invoke（xc-all MCP / `xcode_test`；把 `quicker` 替换成第 2 步查到的 scheme）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS"
}
```

Expected:
- 成功（测试通过）

Commit:
```bash
git add quicker.xcodeproj/project.pbxproj
git commit -m "chore(build): align deployment target and menu-bar app"
```

---

### spawn_agent 1: 领域模型（ClipboardEntry）+ 偏好项 Keys

**Files:**
- Modify: `quicker/quickerApp.swift:1-32`
- Move/Replace: `quicker/Item.swift` → `quicker/Clipboard/ClipboardEntry.swift`
- Add: `quicker/Hotkey/Hotkey.swift`
- Add: `quicker/Settings/PreferencesKeys.swift`
- Test: `quickerTests/PreferencesKeysTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/PreferencesKeysTests.swift`:
```swift
import XCTest
@testable import quicker

final class PreferencesKeysTests: XCTestCase {
    func testDefaultsAreStable() {
        XCTAssertEqual(PreferencesKeys.maxHistoryCount.defaultValue, 200)
        XCTAssertEqual(PreferencesKeys.dedupeAdjacentEnabled.defaultValue, true)
        XCTAssertEqual(PreferencesKeys.hotkey.defaultValue, .default)
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PreferencesKeysTests"]
}
```

Expected: FAIL（`Cannot find 'PreferencesKeys' in scope`）

**Step 3: Write minimal implementation**

Add `quicker/Hotkey/Hotkey.swift`:
```swift
import Carbon
import Foundation

struct Hotkey: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = Hotkey(
        keyCode: 9, // v
        modifiers: UInt32(cmdKey | shiftKey)
    )
}
```

Add `quicker/Settings/PreferencesKeys.swift`:
```swift
import Foundation

enum PreferencesKeys {
    enum maxHistoryCount {
        static let key = "maxHistoryCount"
        static let defaultValue = 200
    }

    enum dedupeAdjacentEnabled {
        static let key = "dedupeAdjacentEnabled"
        static let defaultValue = true
    }

    enum hotkey {
        static let key = "hotkey"
        static let defaultValue = Hotkey.default
    }
}
```

Replace the template model with MVP model:

Create `quicker/Clipboard/ClipboardEntry.swift` (and remove/stop using `Item.swift`):
```swift
import Foundation
import SwiftData

@Model
final class ClipboardEntry {
    var text: String
    var createdAt: Date

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}
```

Update `quicker/quickerApp.swift:13-23` to build a container for `ClipboardEntry` instead of `Item`:
```swift
let schema = Schema([
    ClipboardEntry.self,
])
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PreferencesKeysTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/quickerApp.swift quicker/Clipboard/ClipboardEntry.swift quicker/Hotkey/Hotkey.swift quicker/Settings/PreferencesKeys.swift quickerTests/PreferencesKeysTests.swift
git commit -m "feat(core): add clipboard entry model and preference keys"
```

---

### spawn_agent 2: 纯逻辑——分页与快捷键映射（⌘1..5）

> 目标：把“每页 5 条、翻页、⌘1..5 映射”做成纯函数，先用单测锁住行为（后续 UI/Panel 复用）。

**Files:**
- Add: `quicker/Panel/Pagination.swift`
- Test: `quickerTests/PaginationTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/PaginationTests.swift`:
```swift
import XCTest
@testable import quicker

final class PaginationTests: XCTestCase {
    func testPageCount() {
        XCTAssertEqual(Pagination.pageCount(totalCount: 0, pageSize: 5), 0)
        XCTAssertEqual(Pagination.pageCount(totalCount: 1, pageSize: 5), 1)
        XCTAssertEqual(Pagination.pageCount(totalCount: 5, pageSize: 5), 1)
        XCTAssertEqual(Pagination.pageCount(totalCount: 6, pageSize: 5), 2)
    }

    func testSliceRange() {
        XCTAssertEqual(Pagination.rangeForPage(pageIndex: 0, totalCount: 12, pageSize: 5), 0..<5)
        XCTAssertEqual(Pagination.rangeForPage(pageIndex: 1, totalCount: 12, pageSize: 5), 5..<10)
        XCTAssertEqual(Pagination.rangeForPage(pageIndex: 2, totalCount: 12, pageSize: 5), 10..<12)
    }

    func testCmdNumberMapsToAbsoluteIndex() {
        // total 12 => pages: [0..4], [5..9], [10..11]
        XCTAssertEqual(Pagination.absoluteIndexForCmdNumber(cmdNumber: 1, pageIndex: 0, totalCount: 12, pageSize: 5), 0)
        XCTAssertEqual(Pagination.absoluteIndexForCmdNumber(cmdNumber: 5, pageIndex: 0, totalCount: 12, pageSize: 5), 4)
        XCTAssertEqual(Pagination.absoluteIndexForCmdNumber(cmdNumber: 3, pageIndex: 2, totalCount: 12, pageSize: 5), nil) // page 3 only has 2 items
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PaginationTests"]
}
```
Expected: FAIL（`Cannot find 'Pagination' in scope`）

**Step 3: Write minimal implementation**

Add `quicker/Panel/Pagination.swift`:
```swift
import Foundation

enum Pagination {
    static func pageCount(totalCount: Int, pageSize: Int) -> Int {
        guard totalCount > 0 else { return 0 }
        return Int(ceil(Double(totalCount) / Double(pageSize)))
    }

    static func rangeForPage(pageIndex: Int, totalCount: Int, pageSize: Int) -> Range<Int> {
        let start = max(0, pageIndex) * pageSize
        guard start < totalCount else { return 0..<0 }
        let end = min(totalCount, start + pageSize)
        return start..<end
    }

    static func absoluteIndexForCmdNumber(cmdNumber: Int, pageIndex: Int, totalCount: Int, pageSize: Int) -> Int? {
        guard (1...pageSize).contains(cmdNumber) else { return nil }
        let index = pageIndex * pageSize + (cmdNumber - 1)
        return index < totalCount ? index : nil
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PaginationTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Panel/Pagination.swift quickerTests/PaginationTests.swift
git commit -m "feat(panel): add pagination helper for 5-item pages"
```

---

### spawn_agent 3: 偏好项读写（UserDefaults）+ 可注入（便于测试）

**Files:**
- Add: `quicker/Settings/PreferencesStore.swift`
- Test: `quickerTests/PreferencesStoreTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/PreferencesStoreTests.swift`:
```swift
import XCTest
@testable import quicker

final class PreferencesStoreTests: XCTestCase {
    func testDefaultValues() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = PreferencesStore(userDefaults: defaults)

        XCTAssertEqual(store.maxHistoryCount, PreferencesKeys.maxHistoryCount.defaultValue)
        XCTAssertEqual(store.dedupeAdjacentEnabled, PreferencesKeys.dedupeAdjacentEnabled.defaultValue)
        XCTAssertEqual(store.hotkey, PreferencesKeys.hotkey.defaultValue)
    }

    func testPersistAndReadBack() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = PreferencesStore(userDefaults: defaults)

        store.maxHistoryCount = 10
        store.dedupeAdjacentEnabled = false
        store.hotkey = Hotkey(keyCode: 1, modifiers: 0)

        XCTAssertEqual(store.maxHistoryCount, 10)
        XCTAssertEqual(store.dedupeAdjacentEnabled, false)
        XCTAssertEqual(store.hotkey, Hotkey(keyCode: 1, modifiers: 0))
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PreferencesStoreTests"]
}
```
Expected: FAIL（`Cannot find 'PreferencesStore' in scope`）

**Step 3: Write minimal implementation**

Add `quicker/Settings/PreferencesStore.swift`:
```swift
import Foundation

final class PreferencesStore {
    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    var maxHistoryCount: Int {
        get {
            let value = userDefaults.object(forKey: PreferencesKeys.maxHistoryCount.key) as? Int
            return value ?? PreferencesKeys.maxHistoryCount.defaultValue
        }
        set { userDefaults.set(newValue, forKey: PreferencesKeys.maxHistoryCount.key) }
    }

    var dedupeAdjacentEnabled: Bool {
        get {
            let value = userDefaults.object(forKey: PreferencesKeys.dedupeAdjacentEnabled.key) as? Bool
            return value ?? PreferencesKeys.dedupeAdjacentEnabled.defaultValue
        }
        set { userDefaults.set(newValue, forKey: PreferencesKeys.dedupeAdjacentEnabled.key) }
    }

    var hotkey: Hotkey {
        get {
            guard
                let data = userDefaults.data(forKey: PreferencesKeys.hotkey.key),
                let value = try? JSONDecoder().decode(Hotkey.self, from: data)
            else {
                return PreferencesKeys.hotkey.defaultValue
            }
            return value
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            userDefaults.set(data, forKey: PreferencesKeys.hotkey.key)
        }
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PreferencesStoreTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Settings/PreferencesStore.swift quickerTests/PreferencesStoreTests.swift
git commit -m "feat(settings): add preferences store backed by user defaults"
```

---

### spawn_agent 4: ClipboardStore（SwiftData）——插入/去重/限量/清空

> 目标：先把“相邻去重 + 限量裁剪 + 倒序查询 + 清空”落到 SwiftData，并用 in-memory `ModelContainer` 单测验证。

**Files:**
- Add: `quicker/Clipboard/ClipboardStore.swift`
- Test: `quickerTests/ClipboardStoreTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/ClipboardStoreTests.swift`:
```swift
import XCTest
import SwiftData
@testable import quicker

@MainActor
final class ClipboardStoreTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testInsertAndFetchLatest() throws {
        let container = try makeInMemoryContainer()
        let store = ClipboardStore(modelContainer: container, preferences: PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))

        _ = try store.insert(text: "A")
        _ = try store.insert(text: "B")

        let latest = try store.fetchLatest(limit: 10)
        XCTAssertEqual(latest.map(\.text), ["B", "A"])
    }

    func testDedupeAdjacentEnabled() throws {
        let container = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = PreferencesStore(userDefaults: defaults)
        prefs.dedupeAdjacentEnabled = true
        prefs.maxHistoryCount = 200

        let store = ClipboardStore(modelContainer: container, preferences: prefs)

        XCTAssertEqual(try store.insert(text: "A"), true)
        XCTAssertEqual(try store.insert(text: "A"), false)
        XCTAssertEqual(try store.fetchLatest(limit: 10).map(\.text), ["A"])
    }

    func testMaxHistoryCountTrims() throws {
        let container = try makeInMemoryContainer()
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let prefs = PreferencesStore(userDefaults: defaults)
        prefs.maxHistoryCount = 2
        prefs.dedupeAdjacentEnabled = false

        let store = ClipboardStore(modelContainer: container, preferences: prefs)

        _ = try store.insert(text: "A")
        _ = try store.insert(text: "B")
        _ = try store.insert(text: "C")

        let latest = try store.fetchLatest(limit: 10).map(\.text)
        XCTAssertEqual(latest, ["C", "B"])
    }

    func testClear() throws {
        let container = try makeInMemoryContainer()
        let store = ClipboardStore(modelContainer: container, preferences: PreferencesStore(userDefaults: UserDefaults(suiteName: UUID().uuidString)!))

        _ = try store.insert(text: "A")
        try store.clear()
        XCTAssertEqual(try store.fetchLatest(limit: 10).count, 0)
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardStoreTests"]
}
```
Expected: FAIL（`Cannot find 'ClipboardStore' in scope`）

**Step 3: Write minimal implementation**

Add `quicker/Clipboard/ClipboardStore.swift`:
```swift
import Foundation
import SwiftData

@MainActor
final class ClipboardStore {
    private let modelContainer: ModelContainer
    private let preferences: PreferencesStore

    init(modelContainer: ModelContainer, preferences: PreferencesStore) {
        self.modelContainer = modelContainer
        self.preferences = preferences
    }

    private var context: ModelContext { modelContainer.mainContext }

    func fetchLatest(limit: Int) throws -> [ClipboardEntry] {
        var descriptor = FetchDescriptor<ClipboardEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    @discardableResult
    func insert(text: String, now: Date = .now) throws -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if preferences.dedupeAdjacentEnabled {
            if let latest = try fetchLatest(limit: 1).first, latest.text == trimmed {
                return false
            }
        }

        context.insert(ClipboardEntry(text: trimmed, createdAt: now))
        try context.save()

        try trimToMaxCount()
        return true
    }

    func clear() throws {
        let all = try context.fetch(FetchDescriptor<ClipboardEntry>())
        for entry in all {
            context.delete(entry)
        }
        try context.save()
    }

    func trimToMaxCount() throws {
        let maxCount = max(0, preferences.maxHistoryCount)
        guard maxCount > 0 else {
            try clear()
            return
        }

        let all = try fetchLatest(limit: Int.max)
        guard all.count > maxCount else { return }

        for entry in all.dropFirst(maxCount) {
            context.delete(entry)
        }
        try context.save()
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardStoreTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Clipboard/ClipboardStore.swift quickerTests/ClipboardStoreTests.swift
git commit -m "feat(clipboard): add swiftdata clipboard store with dedupe and trim"
```

---

### spawn_agent 5: 忽略应用列表（IgnoreAppStore）+ NSOpenPanel 选择 .app

> 目标：持久化忽略 bundle id 列表；并提供“从 .app 解析 bundle id”的纯逻辑，单测覆盖重复/无 bundle id 情况。

**Files:**
- Add: `quicker/IgnoreApps/IgnoredApp.swift`
- Add: `quicker/IgnoreApps/IgnoreAppStore.swift`
- Test: `quickerTests/IgnoreAppStoreTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/IgnoreAppStoreTests.swift`:
```swift
import XCTest
@testable import quicker

final class IgnoreAppStoreTests: XCTestCase {
    func testAddAndRemove() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = IgnoreAppStore(userDefaults: defaults)

        try store.add(bundleIdentifier: "com.example.A", displayName: "A", appPath: "/Applications/A.app")
        XCTAssertTrue(store.isIgnored(bundleIdentifier: "com.example.A"))

        store.remove(bundleIdentifier: "com.example.A")
        XCTAssertFalse(store.isIgnored(bundleIdentifier: "com.example.A"))
    }

    func testDedupesByBundleId() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = IgnoreAppStore(userDefaults: defaults)

        try store.add(bundleIdentifier: "com.example.A", displayName: "A", appPath: "/Applications/A.app")
        try store.add(bundleIdentifier: "com.example.A", displayName: "A2", appPath: "/Applications/A2.app")
        XCTAssertEqual(store.all().count, 1)
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/IgnoreAppStoreTests"]
}
```
Expected: FAIL（`Cannot find 'IgnoreAppStore' in scope`）

**Step 3: Write minimal implementation**

Add `quicker/IgnoreApps/IgnoredApp.swift`:
```swift
import Foundation

struct IgnoredApp: Codable, Equatable {
    let bundleIdentifier: String
    var displayName: String?
    var appPath: String?
}
```

Add `quicker/IgnoreApps/IgnoreAppStore.swift`:
```swift
import Foundation

final class IgnoreAppStore {
    private let userDefaults: UserDefaults
    private let key = "ignoredApps"

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func all() -> [IgnoredApp] {
        guard let data = userDefaults.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([IgnoredApp].self, from: data)) ?? []
    }

    func isIgnored(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return all().contains { $0.bundleIdentifier == bundleIdentifier }
    }

    func add(bundleIdentifier: String, displayName: String?, appPath: String?) throws {
        var apps = all()
        apps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        apps.append(IgnoredApp(bundleIdentifier: bundleIdentifier, displayName: displayName, appPath: appPath))
        try save(apps)
    }

    func remove(bundleIdentifier: String) {
        var apps = all()
        apps.removeAll { $0.bundleIdentifier == bundleIdentifier }
        try? save(apps)
    }

    private func save(_ apps: [IgnoredApp]) throws {
        let data = try JSONEncoder().encode(apps)
        userDefaults.set(data, forKey: key)
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/IgnoreAppStoreTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/IgnoreApps/IgnoredApp.swift quicker/IgnoreApps/IgnoreAppStore.swift quickerTests/IgnoreAppStoreTests.swift
git commit -m "feat(privacy): add ignore app store persisted in user defaults"
```

---

### spawn_agent 6: ClipboardMonitor（轮询 NSPasteboard.changeCount）+ 忽略前台 App

> 目标：监听剪贴板变化，仅处理 `.string` 文本；取 `NSWorkspace.shared.frontmostApplication?.bundleIdentifier` 判定是否在忽略列表；命中则不写入 `ClipboardStore`。

**Files:**
- Add: `quicker/Clipboard/ClipboardMonitor.swift`
- Add: `quicker/Clipboard/PasteboardClient.swift`
- Add: `quicker/System/FrontmostAppProvider.swift`
- Test: `quickerTests/ClipboardMonitorLogicTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/ClipboardMonitorLogicTests.swift`（只测“逻辑”，不跑 Timer）:
```swift
import XCTest
@testable import quicker

final class ClipboardMonitorLogicTests: XCTestCase {
    func testSkipsWhenFrontmostAppIsIgnored() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let ignoreStore = IgnoreAppStore(userDefaults: defaults)
        try ignoreStore.add(bundleIdentifier: "com.example.secret", displayName: nil, appPath: nil)

        let store = SpyClipboardStore()
        let logic = ClipboardMonitorLogic(ignoreAppStore: ignoreStore, clipboardStore: store)

        logic.handleClipboardTextChange(text: "A", frontmostBundleId: "com.example.secret")
        XCTAssertEqual(store.inserted, [])
    }

    func testInsertsWhenNotIgnored() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let ignoreStore = IgnoreAppStore(userDefaults: defaults)
        let store = SpyClipboardStore()
        let logic = ClipboardMonitorLogic(ignoreAppStore: ignoreStore, clipboardStore: store)

        logic.handleClipboardTextChange(text: "A", frontmostBundleId: "com.example.ok")
        XCTAssertEqual(store.inserted, ["A"])
    }
}

private final class SpyClipboardStore: ClipboardStoreInserting {
    var inserted: [String] = []
    func insert(text: String) {
        inserted.append(text)
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardMonitorLogicTests"]
}
```
Expected: FAIL（`Cannot find 'ClipboardMonitorLogic' in scope` 等）

**Step 3: Write minimal implementation**

Add `quicker/Clipboard/PasteboardClient.swift`:
```swift
import AppKit

protocol PasteboardClient {
    var changeCount: Int { get }
    func readString() -> String?
}

struct SystemPasteboardClient: PasteboardClient {
    private let pasteboard = NSPasteboard.general

    var changeCount: Int { pasteboard.changeCount }

    func readString() -> String? {
        pasteboard.string(forType: .string)
    }
}
```

Add `quicker/System/FrontmostAppProvider.swift`:
```swift
import AppKit

protocol FrontmostAppProviding {
    var frontmostBundleIdentifier: String? { get }
}

struct SystemFrontmostAppProvider: FrontmostAppProviding {
    var frontmostBundleIdentifier: String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
}
```

Add `quicker/Clipboard/ClipboardMonitor.swift`（先把逻辑拆出来，Timer 后续再接）:
```swift
import Foundation

protocol ClipboardStoreInserting {
    func insert(text: String)
}

struct ClipboardMonitorLogic {
    let ignoreAppStore: IgnoreAppStore
    let clipboardStore: ClipboardStoreInserting

    func handleClipboardTextChange(text: String, frontmostBundleId: String?) {
        guard ignoreAppStore.isIgnored(bundleIdentifier: frontmostBundleId) == false else { return }
        clipboardStore.insert(text: text)
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardMonitorLogicTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Clipboard/ClipboardMonitor.swift quicker/Clipboard/PasteboardClient.swift quicker/System/FrontmostAppProvider.swift quickerTests/ClipboardMonitorLogicTests.swift
git commit -m "feat(clipboard): add monitor logic with ignore-app filtering"
```

---

### spawn_agent 7: ClipboardMonitor（Timer 轮询实现）+ 写入 SwiftData Store

> 目标：把 spawn_agent 6 的纯逻辑接到真实系统：每次 `changeCount` 变化且读到文本时写入 SwiftData `ClipboardStore`。

**Files:**
- Modify: `quicker/Clipboard/ClipboardMonitor.swift`（补全 monitor 实现）
- Modify: `quicker/Clipboard/ClipboardStore.swift`（加一层轻量协议适配）
- Test: `quickerTests/ClipboardMonitorIntegrationStyleTests.swift`（用 fake pasteboard / fake frontmost provider，验证轮询触发逻辑）

**Step 1: Write the failing test**

Create `quickerTests/ClipboardMonitorIntegrationStyleTests.swift`:
```swift
import XCTest
@testable import quicker

final class ClipboardMonitorIntegrationStyleTests: XCTestCase {
    func testPollInsertsWhenChangeCountAdvances() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let ignoreStore = IgnoreAppStore(userDefaults: defaults)
        let store = SpyInsertStore()

        let pasteboard = FakePasteboardClient()
        let frontmost = FakeFrontmostAppProvider(bundleId: "com.example.ok")

        let monitor = ClipboardMonitor(
            pasteboard: pasteboard,
            frontmostAppProvider: frontmost,
            logic: ClipboardMonitorLogic(ignoreAppStore: ignoreStore, clipboardStore: store)
        )

        pasteboard.set(text: "A", changeCount: 1)
        monitor.pollOnce()

        XCTAssertEqual(store.inserted, ["A"])
    }
}

private final class SpyInsertStore: ClipboardStoreInserting {
    var inserted: [String] = []
    func insert(text: String) { inserted.append(text) }
}

private final class FakePasteboardClient: PasteboardClient {
    private(set) var changeCount: Int = 0
    private var text: String?
    func set(text: String?, changeCount: Int) {
        self.text = text
        self.changeCount = changeCount
    }
    func readString() -> String? { text }
}

private struct FakeFrontmostAppProvider: FrontmostAppProviding {
    let bundleId: String?
    var frontmostBundleIdentifier: String? { bundleId }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardMonitorIntegrationStyleTests"]
}
```
Expected: FAIL（`ClipboardMonitor`/`pollOnce()` 未实现）

**Step 3: Write minimal implementation**

Modify `quicker/Clipboard/ClipboardMonitor.swift`（在原文件内追加/替换为完整实现）:
```swift
import Foundation

final class ClipboardMonitor {
    private let pasteboard: PasteboardClient
    private let frontmostAppProvider: FrontmostAppProviding
    private let logic: ClipboardMonitorLogic

    private var lastChangeCount: Int
    private var timer: Timer?

    init(
        pasteboard: PasteboardClient,
        frontmostAppProvider: FrontmostAppProviding,
        logic: ClipboardMonitorLogic
    ) {
        self.pasteboard = pasteboard
        self.frontmostAppProvider = frontmostAppProvider
        self.logic = logic
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(pollInterval: TimeInterval = 0.3) {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.pollOnce()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func pollOnce() {
        let current = pasteboard.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current

        guard let text = pasteboard.readString() else { return }
        logic.handleClipboardTextChange(text: text, frontmostBundleId: frontmostAppProvider.frontmostBundleIdentifier)
    }
}
```

Modify `quicker/Clipboard/ClipboardStore.swift`：让它实现 `ClipboardStoreInserting`（避免 monitor 依赖 SwiftData 细节）:
```swift
extension ClipboardStore: ClipboardStoreInserting {
    func insert(text: String) {
        try? insert(text: text)
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardMonitorIntegrationStyleTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Clipboard/ClipboardMonitor.swift quicker/Clipboard/ClipboardStore.swift quickerTests/ClipboardMonitorIntegrationStyleTests.swift
git commit -m "feat(clipboard): add timer-based pasteboard polling monitor"
```

---

### spawn_agent 8: 全局热键（Carbon HotkeyManager）——注册/更新/回调

> 目标：实现默认 `⌘⇧V`，按下时调用闭包（后续由 PanelController 绑定为 toggle）。此部分很难做稳定单测，优先做“可运行 + 手测步骤”。
>
> 参考技能：@xcode-workflows（排查 `xcode_build`/`xcode_test`/签名/运行问题）

**Files:**
- Add: `quicker/Hotkey/HotkeyManager.swift`

**Step 1: Write the failing “test” (编译型验证)**

在本阶段用“编译通过 + 手测步骤”替代单测（Carbon API 属于系统集成点，单测价值低且易脆）。

**Step 2: Build to verify it fails (before implementation)**

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```
Expected: （当前没有 HotkeyManager，不会失败；此步可跳过）

**Step 3: Write minimal implementation**

Add `quicker/Hotkey/HotkeyManager.swift`:
```swift
import Carbon
import Foundation

final class HotkeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handlerId = EventHotKeyID(signature: OSType(0x514B484B), id: 1) // "QKHK"

    private let onHotkey: () -> Void

    init(onHotkey: @escaping () -> Void) {
        self.onHotkey = onHotkey
    }

    @discardableResult
    func register(_ hotkey: Hotkey) -> OSStatus {
        unregister()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onHotkey()
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)

        let status = RegisterEventHotKey(hotkey.keyCode, hotkey.modifiers, handlerId, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { hotKeyRef = nil }
        return status
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregister()
    }
}
```

**Step 4: Build to verify it passes**

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```
Expected: 成功（build 通过）

**Step 5: Commit**

```bash
git add quicker/Hotkey/HotkeyManager.swift
git commit -m "feat(hotkey): add carbon global hotkey manager"
```

**Manual verification checklist (此阶段必须做)：**
- Run App（Xcode 运行）
- 在任意前台 App 中按 `⌘⇧V`，确认回调被触发（先用 `Logger` 打印或断点）
- 若 `register(...)` 返回非 `noErr`：在 UI 上给出“可能冲突”的轻提示（实现入口在设置页/热键配置阶段）

---

### spawn_agent 9: PasteService（写剪贴板 + 有权限则模拟 ⌘V，否则降级提示）

> 目标：封装“粘贴动作”；把权限判断与 `CGEvent` 发送集中在一个服务里，UI/Panel 只调用 `paste(text:)`。

**Files:**
- Add: `quicker/Paste/PasteService.swift`
- Add: `quicker/Paste/AccessibilityPermission.swift`
- Add: `quicker/Paste/SystemPasteboardWriter.swift`

**Step 1: Write the failing test (纯逻辑/可注入)**

Create `quickerTests/PasteServiceLogicTests.swift`（只测分支选择，不真正发 CGEvent）:
```swift
import XCTest
@testable import quicker

final class PasteServiceLogicTests: XCTestCase {
    func testFallsBackWhenNotTrusted() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: false)
        let service = PasteService(writer: writer, eventSender: events, permission: permission)

        let result = service.paste(text: "A")
        XCTAssertEqual(writer.written, ["A"])
        XCTAssertEqual(events.sentCount, 0)
        XCTAssertEqual(result, .copiedOnly)
    }

    func testSendsCmdVWhenTrusted() {
        let writer = SpyPasteboardWriter()
        let events = SpyPasteEventSender()
        let permission = FakeAccessibilityPermission(isTrusted: true)
        let service = PasteService(writer: writer, eventSender: events, permission: permission)

        let result = service.paste(text: "A")
        XCTAssertEqual(writer.written, ["A"])
        XCTAssertEqual(events.sentCount, 1)
        XCTAssertEqual(result, .pasted)
    }
}

private final class SpyPasteboardWriter: PasteboardWriting {
    var written: [String] = []
    func writeString(_ string: String) { written.append(string) }
}

private final class SpyPasteEventSender: PasteEventSending {
    var sentCount = 0
    func sendCmdV() { sentCount += 1 }
}

private struct FakeAccessibilityPermission: AccessibilityPermissionChecking {
    let isTrusted: Bool
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool { isTrusted }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PasteServiceLogicTests"]
}
```
Expected: FAIL（`PasteService`/协议未定义）

**Step 3: Write minimal implementation**

Add `quicker/Paste/SystemPasteboardWriter.swift`:
```swift
import AppKit

protocol PasteboardWriting {
    func writeString(_ string: String)
}

struct SystemPasteboardWriter: PasteboardWriting {
    func writeString(_ string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
    }
}
```

Add `quicker/Paste/AccessibilityPermission.swift`:
```swift
import ApplicationServices

protocol AccessibilityPermissionChecking {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool
}

struct SystemAccessibilityPermission: AccessibilityPermissionChecking {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: promptIfNeeded] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
```

Add `quicker/Paste/PasteService.swift`:
```swift
import Foundation

protocol PasteEventSending {
    func sendCmdV()
}

enum PasteResult: Equatable {
    case pasted
    case copiedOnly
}

final class PasteService {
    private let writer: PasteboardWriting
    private let eventSender: PasteEventSending
    private let permission: AccessibilityPermissionChecking

    init(
        writer: PasteboardWriting = SystemPasteboardWriter(),
        eventSender: PasteEventSending = SystemPasteEventSender(),
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()
    ) {
        self.writer = writer
        self.eventSender = eventSender
        self.permission = permission
    }

    func paste(text: String) -> PasteResult {
        writer.writeString(text)
        guard permission.isProcessTrusted(promptIfNeeded: false) else { return .copiedOnly }
        eventSender.sendCmdV()
        return .pasted
    }
}

struct SystemPasteEventSender: PasteEventSending {
    func sendCmdV() {
        // 真实实现放下一步：这里先留空，让单测先跑通
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/PasteServiceLogicTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Paste/PasteService.swift quicker/Paste/AccessibilityPermission.swift quicker/Paste/SystemPasteboardWriter.swift quickerTests/PasteServiceLogicTests.swift
git commit -m "feat(paste): add paste service with accessibility-based fallback"
```

---

### spawn_agent 10: PasteService（真实 CGEvent ⌘V 发送）+ 设置页跳转系统权限

**Files:**
- Modify: `quicker/Paste/PasteService.swift`（实现 `SystemPasteEventSender.sendCmdV()`）
- Add: `quicker/System/SystemSettingsDeepLink.swift`

**Step 1: Write the failing test**

此处同 spawn_agent 8：系统集成点，不做脆弱单测；用手测+最小日志确认。

**Step 2: Build to verify it passes (after implementation)**

Modify `quicker/Paste/PasteService.swift`:
```swift
import CoreGraphics

struct SystemPasteEventSender: PasteEventSending {
    func sendCmdV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // kVK_ANSI_V
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
```

Add `quicker/System/SystemSettingsDeepLink.swift`（设置页按钮用）:
```swift
import AppKit

enum SystemSettingsDeepLink {
    static func openAccessibilityPrivacy() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}
```

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```
Expected: 成功（build 通过）

Commit:
```bash
git add quicker/Paste/PasteService.swift quicker/System/SystemSettingsDeepLink.swift
git commit -m "feat(paste): implement cmd+v via cgevent and add settings deeplink"
```

**Manual verification checklist (此阶段必须做)：**
- 未授权辅助功能时：执行粘贴动作 -> 不自动粘贴，只写剪贴板（手动 `⌘V` 可粘贴）
- 授权辅助功能后：执行粘贴动作 -> 自动触发 `⌘V` 粘贴到前台 App 输入框

---

### spawn_agent 11: PanelViewModel（选择/翻页/关闭）+ 绑定 ClipboardStore/PasteService

> 目标：把面板交互做成可测的 view model：`↑/↓`、`←/→`、`Enter`、`⌘1..5`。

**Files:**
- Add: `quicker/Panel/ClipboardPanelViewModel.swift`
- Test: `quickerTests/ClipboardPanelViewModelTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/ClipboardPanelViewModelTests.swift`:
```swift
import XCTest
@testable import quicker

@MainActor
final class ClipboardPanelViewModelTests: XCTestCase {
    func testDefaultSelectionIsFirstItem() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: ["A", "B", "C"])
        XCTAssertEqual(vm.selectedIndexInPage, 0)
        XCTAssertEqual(vm.selectedText, "A")
    }

    func testArrowDownMovesSelection() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: ["A", "B", "C"])
        vm.moveSelectionDown()
        XCTAssertEqual(vm.selectedText, "B")
    }

    func testCmdNumberPastesOnlyWhenExists() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: ["A", "B"])
        XCTAssertEqual(vm.textForCmdNumber(3), nil)
        XCTAssertEqual(vm.textForCmdNumber(2), "B")
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardPanelViewModelTests"]
}
```
Expected: FAIL（`ClipboardPanelViewModel` 未定义）

**Step 3: Write minimal implementation**

Add `quicker/Panel/ClipboardPanelViewModel.swift`:
```swift
import Foundation

@MainActor
final class ClipboardPanelViewModel: ObservableObject {
    let pageSize: Int

    @Published private(set) var entries: [String]
    @Published private(set) var pageIndex: Int = 0
    @Published private(set) var selectedIndexInPage: Int = 0

    init(pageSize: Int = 5, entries: [String] = []) {
        self.pageSize = pageSize
        self.entries = entries
    }

    var pageCount: Int { Pagination.pageCount(totalCount: entries.count, pageSize: pageSize) }

    var visibleRange: Range<Int> {
        Pagination.rangeForPage(pageIndex: pageIndex, totalCount: entries.count, pageSize: pageSize)
    }

    var visibleEntries: ArraySlice<String> {
        entries[visibleRange]
    }

    var selectedText: String? {
        let absoluteIndex = visibleRange.lowerBound + selectedIndexInPage
        guard absoluteIndex < entries.count else { return nil }
        return entries[absoluteIndex]
    }

    func setEntries(_ newEntries: [String]) {
        entries = newEntries
        pageIndex = 0
        selectedIndexInPage = 0
    }

    func moveSelectionUp() {
        selectedIndexInPage = max(0, selectedIndexInPage - 1)
    }

    func moveSelectionDown() {
        let maxIndex = max(0, visibleEntries.count - 1)
        selectedIndexInPage = min(maxIndex, selectedIndexInPage + 1)
    }

    func previousPage() {
        pageIndex = max(0, pageIndex - 1)
        selectedIndexInPage = 0
    }

    func nextPage() {
        pageIndex = min(max(0, pageCount - 1), pageIndex + 1)
        selectedIndexInPage = 0
    }

    func textForCmdNumber(_ number: Int) -> String? {
        guard let absolute = Pagination.absoluteIndexForCmdNumber(cmdNumber: number, pageIndex: pageIndex, totalCount: entries.count, pageSize: pageSize) else {
            return nil
        }
        return entries[absolute]
    }
}
```

**Step 4: Run test to verify it passes**

Invoke（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS",
  "only_testing": ["quickerTests/ClipboardPanelViewModelTests"]
}
```
Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Panel/ClipboardPanelViewModel.swift quickerTests/ClipboardPanelViewModelTests.swift
git commit -m "feat(panel): add view model for selection and paging"
```

---

### spawn_agent 12: Panel UI（SwiftUI）+ 键盘事件捕获（Esc/Enter/箭头/⌘1..5）

> 目标：实现 `ClipboardPanelView` 显示 5 条列表 + 页码；并通过 `NSViewRepresentable` 捕获 keyDown，调用 view model。

**Files:**
- Add: `quicker/Panel/ClipboardPanelView.swift`
- Add: `quicker/Panel/KeyEventHandlingView.swift`

**Step 1: 手测优先（UI 集成点，不做脆弱单测）**

Add `quicker/Panel/KeyEventHandlingView.swift`:
```swift
import AppKit
import SwiftUI

struct KeyEventHandlingView: NSViewRepresentable {
    var onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyCatcherView()
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class KeyCatcherView: NSView {
    var onKeyDown: ((NSEvent) -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) { onKeyDown?(event) }
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
}
```

Add `quicker/Panel/ClipboardPanelView.swift`:
```swift
import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    @Environment(\.openSettings) private var openSettings
    var onClose: () -> Void
    var onPaste: (String) -> Void

    var body: some View {
        ZStack {
            KeyEventHandlingView { event in
                handleKeyDown(event)
            }
            VStack(alignment: .leading, spacing: 10) {
                header
                content
            }
            .padding(16)
            .frame(width: 520, height: 240)
        }
    }

    private var header: some View {
        HStack {
            Text("Clipboard")
                .font(.headline)
            Spacer()
            Text(pageLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var pageLabel: String {
        let total = viewModel.pageCount
        guard total > 0 else { return "0/0" }
        return "\(viewModel.pageIndex + 1)/\(total)"
    }

    private var content: some View {
        Group {
            if viewModel.entries.isEmpty {
                Text("暂无历史记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(viewModel.visibleEntries.enumerated()), id: \.offset) { idx, text in
                        row(text: text, isSelected: idx == viewModel.selectedIndexInPage)
                    }
                    Spacer()
                }
            }
        }
    }

    private func row(text: String, isSelected: Bool) -> some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onClose()
            return
        }

        // 重要：面板内 `⌘,` 需要关闭面板并打开 Settings scene（不会经过 app menu 的默认 `⌘,`）
        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
            onClose()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            return
        }

        if event.keyCode == 36 { // Return
            if let text = viewModel.selectedText { onPaste(text) }
            return
        }
        switch event.keyCode {
        case 125: viewModel.moveSelectionDown() // ↓
        case 126: viewModel.moveSelectionUp() // ↑
        case 123: viewModel.previousPage() // ←
        case 124: viewModel.nextPage() // →
        default:
            break
        }

        if event.modifierFlags.contains(.command) {
            if let number = Int(event.charactersIgnoringModifiers ?? ""), (1...viewModel.pageSize).contains(number) {
                if let text = viewModel.textForCmdNumber(number) { onPaste(text) }
            }
        }
    }
}
```

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```
Expected: 成功（build 通过）

Commit:
```bash
git add quicker/Panel/ClipboardPanelView.swift quicker/Panel/KeyEventHandlingView.swift
git commit -m "feat(panel): add swiftui clipboard panel view with key handling"
```

---

### spawn_agent 13: PanelController（NSPanel）——居中显示/失焦关闭/toggle

**Files:**
- Add: `quicker/Panel/CenteredPanel.swift`
- Add: `quicker/Panel/PanelController.swift`

**Step 1: 手测优先**

Add `quicker/Panel/CenteredPanel.swift`:
```swift
import AppKit

final class CenteredPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
```

Add `quicker/Panel/PanelController.swift`:
```swift
import AppKit
import SwiftUI

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private var panel: CenteredPanel?
    private let viewModel: ClipboardPanelViewModel
    private let onPaste: (String, NSRunningApplication?) -> Void
    private var previousFrontmostApp: NSRunningApplication?

    init(viewModel: ClipboardPanelViewModel, onPaste: @escaping (String, NSRunningApplication?) -> Void) {
        self.viewModel = viewModel
        self.onPaste = onPaste
    }

    func toggle() {
        if panel?.isVisible == true {
            close()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }

        // 关键：面板会激活 Quicker，自身会成为前台；粘贴必须回到“唤出前的前台 App”
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication

        center(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makePanel() -> CenteredPanel {
        let content = ClipboardPanelView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.close()
            },
            onPaste: { [weak self] text in
                guard let self else { return }
                self.close()
                self.onPaste(text, self.previousFrontmostApp)
            }
        )

        let hosting = NSHostingController(rootView: content)
        let panel = CenteredPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 240),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentViewController = hosting
        return panel
    }

    private func preferredScreen() -> NSScreen? {
        // 多屏/全屏：优先以鼠标所在屏幕作为“当前工作空间”
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    private func center(_ panel: NSWindow) {
        guard let screen = preferredScreen() else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        let origin = CGPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2
        )
        panel.setFrameOrigin(origin)
    }
}
```

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```

Commit:
```bash
git add quicker/Panel/CenteredPanel.swift quicker/Panel/PanelController.swift
git commit -m "feat(panel): add nsPanel controller with toggle and resign-close"
```

**Manual verification checklist (此阶段必须做)：**
- `Esc` 关闭面板
- 点击面板外关闭
- 切换 App（例如 `⌘Tab`）后面板关闭
- 在前台 App 的输入框中：打开面板 → 选择一条 → 需粘贴回“唤出前的前台 App”（不是 Quicker）

---

### spawn_agent 14: Settings UI（⌘,）+ 偏好项/忽略列表/清空/权限引导

> 目标：实现 Tab：通用/剪切板/关于；“选择应用…” 用 `NSOpenPanel`；提供打开系统权限按钮。

**Files:**
- Add: `quicker/Settings/SettingsView.swift`
- Add: `quicker/Settings/GeneralSettingsView.swift`
- Add: `quicker/Settings/ClipboardSettingsView.swift`
- Add: `quicker/Settings/AboutView.swift`
- Add: `quicker/Settings/OpenPanelAppPicker.swift`
- Add: `quicker/Hotkey/HotkeyRecorderView.swift`

**Step 1: Build-driven（UI）**

Add `quicker/Settings/OpenPanelAppPicker.swift`:
```swift
import AppKit
import UniformTypeIdentifiers

enum OpenPanelAppPicker {
    static func pickAppUrl() -> URL? {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.applicationBundle] // 仅 .app
        return panel.runModal() == .OK ? panel.url : nil
    }
}
```

Add `quicker/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    @State private var tab: String = "general"

    var body: some View {
        TabView(selection: $tab) {
            GeneralSettingsView()
                .tabItem { Text("通用") }
                .tag("general")
            ClipboardSettingsView()
                .tabItem { Text("剪切板") }
                .tag("clipboard")
            AboutView()
                .tabItem { Text("关于") }
                .tag("about")
        }
        .padding(16)
        .frame(width: 560, height: 420)
    }
}
```

Add `quicker/Hotkey/HotkeyRecorderView.swift`（设置页录制快捷键：只负责捕获并回调，不直接注册全局热键）:
```swift
import AppKit
import SwiftUI

struct HotkeyRecorderView: NSViewRepresentable {
    var onCapture: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = RecorderView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class RecorderView: NSView {
    var onCapture: ((NSEvent) -> Void)?
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        onCapture?(event)
    }
}
```

Add `quicker/Settings/GeneralSettingsView.swift`（MVP：自启先留占位；本阶段先实现“快捷键设置入口 + 写入偏好项”，实际注册与冲突提示在 spawn_agent 15 接入 `HotkeyManager` 后完成）:
```swift
import Carbon
import SwiftUI

struct GeneralSettingsView: View {
    @State private var hotkey: Hotkey = PreferencesKeys.hotkey.defaultValue
    @State private var isRecordingHotkey = false

    private let preferences = PreferencesStore()

    var body: some View {
        Form {
            Section("唤出快捷键") {
                HStack {
                    Text("当前：\(hotkeyDisplay)")
                    Spacer()
                    Button("修改…") { isRecordingHotkey = true }
                }
                Text("提示：若与系统/其他应用冲突，可能无法生效（下一步会加“冲突提示”）。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("开机自启") {
                Text("MVP：下一步接入 SMAppService")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { hotkey = preferences.hotkey }
        .sheet(isPresented: $isRecordingHotkey) {
            VStack(alignment: .leading, spacing: 12) {
                Text("按下新的快捷键（建议包含 ⌘）").font(.headline)
                Text("按 Esc 取消").foregroundStyle(.secondary)
                HotkeyRecorderView { event in
                    if event.keyCode == 53 { // Esc
                        isRecordingHotkey = false
                        return
                    }

                    // MVP：只接受包含 ⌘ 的组合；更严格校验与冲突提示在 spawn_agent 15 接入
                    guard event.modifierFlags.contains(.command) else { return }

                    let modifiers = carbonModifiers(from: event.modifierFlags)
                    let captured = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                    hotkey = captured
                    preferences.hotkey = captured
                    isRecordingHotkey = false
                }
                Spacer()
            }
            .padding(16)
            .frame(width: 420, height: 180)
        }
    }

    private var hotkeyDisplay: String {
        // MVP：先保证默认值显示正确；后续可完善 keyCode -> 字符映射
        if hotkey == .default { return "⌘⇧V" }
        return "keyCode \(hotkey.keyCode)"
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}
```

Add `quicker/Settings/ClipboardSettingsView.swift`（绑定 `PreferencesStore` 与 `IgnoreAppStore`，此处建议用 Environment 注入，先用临时实例占位，下一步在 AppState 统一注入）:
```swift
import AppKit
import SwiftUI

struct ClipboardSettingsView: View {
    @State private var maxHistoryCount: Int = PreferencesKeys.maxHistoryCount.defaultValue
    @State private var dedupeAdjacentEnabled: Bool = PreferencesKeys.dedupeAdjacentEnabled.defaultValue
    @State private var ignoredApps: [IgnoredApp] = []
    @State private var isConfirmingClearHistory = false

    private let preferences = PreferencesStore()
    private let ignoreStore = IgnoreAppStore()

    var body: some View {
        Form {
            Section("历史") {
                Stepper(value: $maxHistoryCount, in: 0...5000, step: 10) {
                    Text("最大历史条数：\(maxHistoryCount)")
                }
                Toggle("相邻去重", isOn: $dedupeAdjacentEnabled)
                Button("立即保存") { save() }
            }

            Section("忽略应用") {
                Button("选择应用…") { pickApp() }
                List {
                    ForEach(ignoredApps, id: \.bundleIdentifier) { app in
                        HStack(spacing: 8) {
                            if let path = app.appPath {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                                    .resizable()
                                    .frame(width: 20, height: 20)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(app.displayName ?? app.bundleIdentifier)
                                Text(app.bundleIdentifier).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete(perform: deleteApps)
                }
                .frame(height: 140)
            }

            Section("隐私与权限") {
                Text("应用会读取剪贴板用于历史功能；可通过忽略应用/限量/清空降低暴露面。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button("打开“辅助功能”系统设置") {
                    SystemSettingsDeepLink.openAccessibilityPrivacy()
                }
            }

            Section("危险操作") {
                Button("清空历史") { isConfirmingClearHistory = true }
                .foregroundStyle(.red)
                .confirmationDialog("确认清空所有历史？", isPresented: $isConfirmingClearHistory) {
                    Button("清空", role: .destructive) {
                        // 下一步接 ClipboardStore.clear() + 刷新面板
                    }
                    Button("取消", role: .cancel) {}
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        maxHistoryCount = preferences.maxHistoryCount
        dedupeAdjacentEnabled = preferences.dedupeAdjacentEnabled
        ignoredApps = ignoreStore.all()
    }

    private func save() {
        preferences.maxHistoryCount = maxHistoryCount
        preferences.dedupeAdjacentEnabled = dedupeAdjacentEnabled
        // 下一步（spawn_agent 15 接入 ClipboardStore 后）需要：
        // - 立即 trimToMaxCount（满足“变更后立即裁剪”）
        // - 刷新面板 entries
    }

    private func pickApp() {
        guard let url = OpenPanelAppPicker.pickAppUrl(),
              let bundle = Bundle(url: url),
              let bundleId = bundle.bundleIdentifier else { return }

        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String

        try? ignoreStore.add(bundleIdentifier: bundleId, displayName: name, appPath: url.path)
        ignoredApps = ignoreStore.all()
    }

    private func deleteApps(at offsets: IndexSet) {
        for i in offsets {
            ignoreStore.remove(bundleIdentifier: ignoredApps[i].bundleIdentifier)
        }
        ignoredApps = ignoreStore.all()
    }
}
```

Add `quicker/Settings/AboutView.swift`:
```swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Quicker")
                .font(.title2)
            Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0") (\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"))")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
```

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```

Commit:
```bash
git add quicker/Settings/SettingsView.swift quicker/Settings/GeneralSettingsView.swift quicker/Settings/ClipboardSettingsView.swift quicker/Settings/AboutView.swift quicker/Settings/OpenPanelAppPicker.swift quicker/Hotkey/HotkeyRecorderView.swift
git commit -m "feat(settings): add tabbed settings UI and ignore-app picker"
```

---

### spawn_agent 15: AppState（依赖注入）+ MenuBarExtra 菜单 + Commands（⌘, 互斥）

> 目标：把服务统一装配：`ModelContainer`、`ClipboardStore`、`IgnoreAppStore`、`ClipboardMonitor`、`PanelController`、`HotkeyManager`、`PasteService`；并用 `MenuBarExtra` 替换模板 `WindowGroup`。

**Files:**
- Add: `quicker/App/AppState.swift`
- Modify: `quicker/quickerApp.swift:1-32`
- Modify: `quicker/Settings/SettingsView.swift`
- Modify: `quicker/Settings/GeneralSettingsView.swift`
- Modify: `quicker/Settings/ClipboardSettingsView.swift`
- Add: `quicker/UI/ToastPresenter.swift`
- Delete/Stop using: `quicker/ContentView.swift`

**Step 1: Build-driven（集成）**

Add `quicker/App/AppState.swift`:
```swift
import AppKit
import Carbon
import Foundation
import SwiftData

@MainActor
final class AppState: ObservableObject {
    let modelContainer: ModelContainer
    let preferences: PreferencesStore
    let ignoreAppStore: IgnoreAppStore
    let clipboardStore: ClipboardStore
    let pasteService: PasteService
    let panelViewModel: ClipboardPanelViewModel
    let panelController: PanelController
    let clipboardMonitor: ClipboardMonitor
    let hotkeyManager: HotkeyManager
    let toast: ToastPresenter

    @Published private(set) var hotkeyRegisterStatus: OSStatus = noErr

    init() {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        self.modelContainer = try! ModelContainer(for: schema, configurations: [config])

        self.preferences = PreferencesStore()
        self.ignoreAppStore = IgnoreAppStore()
        self.clipboardStore = ClipboardStore(modelContainer: modelContainer, preferences: preferences)
        self.pasteService = PasteService()
        self.toast = ToastPresenter()

        self.panelViewModel = ClipboardPanelViewModel(pageSize: 5)
        self.panelController = PanelController(viewModel: panelViewModel) { [weak self] text, previousApp in
            self?.pasteFromPanel(text: text, previousApp: previousApp)
        }

        self.clipboardMonitor = ClipboardMonitor(
            pasteboard: SystemPasteboardClient(),
            frontmostAppProvider: SystemFrontmostAppProvider(),
            logic: ClipboardMonitorLogic(ignoreAppStore: ignoreAppStore, clipboardStore: clipboardStore)
        )

        self.hotkeyManager = HotkeyManager { [weak self] in
            // 口径：热键打开面板前刷新 entries（避免内容陈旧）
            self?.togglePanel()
        }
    }

    func start() {
        clipboardMonitor.start()
        hotkeyRegisterStatus = hotkeyManager.register(preferences.hotkey)
    }

    func togglePanel() {
        refreshPanelEntries()
        panelController.toggle()
    }

    func refreshPanelEntries() {
        let items = (try? clipboardStore.fetchLatest(limit: 500)) ?? []
        panelViewModel.setEntries(items.map(\.text))
    }

    func applyHotkey(_ hotkey: Hotkey) {
        preferences.hotkey = hotkey
        hotkeyRegisterStatus = hotkeyManager.register(hotkey)
    }

    func pasteFromPanel(text: String, previousApp: NSRunningApplication?) {
        // 口径：无辅助功能权限时，仍立即关闭面板（PanelController 已关闭），这里负责“copy-only 轻提示”
        if SystemAccessibilityPermission().isProcessTrusted(promptIfNeeded: false) {
            previousApp?.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [pasteService] in
                _ = pasteService.paste(text: text)
            }
        } else {
            _ = pasteService.paste(text: text)
            toast.show(message: "未开启辅助功能，已复制到剪贴板（可手动 ⌘V）")
        }
    }

    func confirmAndClearHistory() {
        let alert = NSAlert()
        alert.messageText = "确认清空所有历史？"
        alert.informativeText = "此操作不可撤销。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            try? clipboardStore.clear()
            refreshPanelEntries()
        }
    }
}
```

Add `quicker/UI/ToastPresenter.swift`（copy-only 场景的非阻塞轻提示；不申请通知权限，不弹 modal）:
```swift
import AppKit
import SwiftUI

@MainActor
final class ToastPresenter {
    private var window: NSWindow?

    func show(message: String, duration: TimeInterval = 1.2) {
        window?.orderOut(nil)

        let view = Text(message)
            .font(.system(size: 13))
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

        let hosting = NSHostingController(rootView: view)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 56),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentViewController = hosting

        center(panel)
        panel.orderFrontRegardless()
        window = panel

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            self?.window?.orderOut(nil)
            self?.window = nil
        }
    }

    private func center(_ window: NSWindow) {
        let point = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        guard let screen else { return }

        let frame = screen.visibleFrame
        let size = window.frame.size
        let origin = CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
        window.setFrameOrigin(origin)
    }
}
```

Modify `quicker/quickerApp.swift`（用 `MenuBarExtra` + `Settings`；并在启动后 `start()`）:
```swift
import SwiftUI

@main
struct QuickerApp: App {
    @StateObject private var appState: AppState

    init() {
        let state = AppState()
        _appState = StateObject(wrappedValue: state)
        DispatchQueue.main.async { state.start() }
    }

    var body: some Scene {
        MenuBarExtra("Quicker") {
            Button("Open Clipboard Panel") {
                appState.togglePanel()
            }
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Clear History") {
                appState.confirmAndClearHistory()
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}
```

接入设置依赖（避免 spawn_agent 14 的“临时实例”导致无法立即裁剪/无法冲突提示）：

Modify `quicker/Settings/GeneralSettingsView.swift`：改为通过 `@EnvironmentObject` 读取 `AppState`，录制后调用 `appState.applyHotkey(...)`，并在 `appState.hotkeyRegisterStatus != noErr` 时显示冲突提示。

Modify `quicker/Settings/ClipboardSettingsView.swift`：保存时立即 `trimToMaxCount()` 并刷新面板；清空历史的确认按钮接入 `clipboardStore.clear()` 并刷新面板。

示例（只展示关键差异，省略 UI 细节）：
```swift
struct ClipboardSettingsView: View {
    @EnvironmentObject private var appState: AppState

    private var preferences: PreferencesStore { appState.preferences }

    private func save() {
        preferences.maxHistoryCount = maxHistoryCount
        preferences.dedupeAdjacentEnabled = dedupeAdjacentEnabled
        try? appState.clipboardStore.trimToMaxCount()
        appState.refreshPanelEntries()
    }

    private func clearHistory() {
        try? appState.clipboardStore.clear()
        appState.refreshPanelEntries()
    }
}
```

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```

Commit:
```bash
git add quicker/App/AppState.swift quicker/quickerApp.swift quicker/UI/ToastPresenter.swift quicker/Settings/SettingsView.swift quicker/Settings/GeneralSettingsView.swift quicker/Settings/ClipboardSettingsView.swift
git commit -m "feat(app): wire services and add menu bar scene + settings command"
```

**Manual verification checklist (此阶段必须做)：**
- 菜单栏出现 Quicker 项；无 Dock 图标
- 菜单 `Open Clipboard Panel` 可打开/关闭面板
- `⌘⇧V` 可 toggle 面板，且打开前会刷新列表
- `⌘,` 打开 Settings，且若面板打开会先关闭
- `Clear History` 有二次确认；清空后面板空态
- 设置页修改最大条数后：立即裁剪（不等下一次复制）
- 设置页修改快捷键后：立即生效；若注册失败（`register != noErr`）显示“可能冲突”提示
- 无辅助功能权限：选择条目后立即关闭面板，并显示“已复制到剪贴板（可手动 ⌘V）”轻提示
- 有辅助功能权限：选择条目后，能粘贴回“唤出前的前台 App”

---

### spawn_agent 16: 开机自启（SMAppService）+ 设置页开关

> 目标：按 PRD 在 macOS 14+ 支持“开机自启”开关。此处实现细节可能受 Sandbox/签名/分发方式影响，建议先做“可观测的最小实现”并在真机验证。
>
> 参考技能：@xcode-workflows

**Files:**
- Modify: `quicker/Settings/GeneralSettingsView.swift`
- Add: `quicker/Startup/LaunchAtLoginService.swift`

**Step 1: Build-driven + 手测**

Add `quicker/Startup/LaunchAtLoginService.swift`:
```swift
import ServiceManagement

@MainActor
final class LaunchAtLoginService: ObservableObject {
    @Published private(set) var isEnabled: Bool = false

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // MVP：先不弹复杂错误面板；可用 Logger 记录
        }
        refresh()
    }
}
```

Modify `quicker/Settings/GeneralSettingsView.swift`:
```swift
import Carbon
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hotkey: Hotkey = PreferencesKeys.hotkey.defaultValue
    @State private var isRecordingHotkey = false
    @StateObject private var launch = LaunchAtLoginService()

    var body: some View {
        Form {
            Section("唤出快捷键") {
                HStack {
                    Text("当前：\(hotkeyDisplay)")
                    Spacer()
                    Button("修改…") { isRecordingHotkey = true }
                }
                if appState.hotkeyRegisterStatus != noErr {
                    Text("可能与系统/其他应用冲突，建议换一个组合。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("开机自启") {
                Toggle("开机自启", isOn: Binding(
                    get: { launch.isEnabled },
                    set: { launch.setEnabled($0) }
                ))
                .onAppear { launch.refresh() }
            }
        }
        .onAppear { hotkey = appState.preferences.hotkey }
        .sheet(isPresented: $isRecordingHotkey) {
            VStack(alignment: .leading, spacing: 12) {
                Text("按下新的快捷键（建议包含 ⌘）").font(.headline)
                Text("按 Esc 取消").foregroundStyle(.secondary)
                HotkeyRecorderView { event in
                    if event.keyCode == 53 { // Esc
                        isRecordingHotkey = false
                        return
                    }
                    guard event.modifierFlags.contains(.command) else { return }

                    let modifiers = carbonModifiers(from: event.modifierFlags)
                    let captured = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                    hotkey = captured
                    appState.applyHotkey(captured)
                    isRecordingHotkey = false
                }
                Spacer()
            }
            .padding(16)
            .frame(width: 420, height: 180)
        }
    }

    private var hotkeyDisplay: String {
        if hotkey == .default { return "⌘⇧V" }
        return "keyCode \(hotkey.keyCode)"
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}
```

Build（xc-all MCP / `xcode_build`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "configuration": "Debug",
  "destination": "platform=macOS"
}
```

Commit:
```bash
git add quicker/Startup/LaunchAtLoginService.swift quicker/Settings/GeneralSettingsView.swift
git commit -m "feat(startup): add launch-at-login toggle via SMAppService"
```

**Manual verification checklist (此阶段必须做)：**
- 在设置里打开“开机自启”，系统登录项中能看到/生效
- 关闭后能移除/不再启动

---

## 2. 最终回归（MVP）

Run full tests（xc-all MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS"
}
```
Expected: 成功（测试通过）

手动验收（逐条过 `docs/plans/2026-02-04-quicker-mvp-design.md` 的“手测验收清单”）：
- 热键（含设置可改）、Esc、失焦关闭、分页、页码、Enter、⌘1..5、面板内 `⌘,`
- 设置互斥、偏好项生效（最大条数裁剪、去重、忽略 app、清空）
- 重启后历史仍存在
- 无辅助功能权限：降级为 copy-only + 轻提示；有权限：自动粘贴且粘贴回“唤出前的前台 App”

---

## 执行交接

计划已完成并保存到 `docs/plans/2026-02-04-quicker-mvp-implementation-plan.md`。两种执行方式：

1) **spawn_agent-Driven（本 session）**：我按步骤派发子 agent，每步 review，迭代更快（REQUIRED SUB-SKILL: `superpowers-subagent-driven-development`）
2) **Parallel Session（新 session）**：你开新 session，用 `superpowers-executing-plans` 按 task-by-task 执行

你想选哪一种？
