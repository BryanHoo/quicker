# Accessibility + 键盘导航 + 剪贴板性能优化 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 提升剪贴板/文本块面板在 VoiceOver 与键盘下的可操作性，避免未处理按键被吞，并减少剪贴板轮询与清理的无谓开销。

**Architecture:** 以最小、局部改动为原则：
- 把面板列表条目的 `.onTapGesture` 改为语义化 `Button`（避免嵌套按钮的场景不强改）。
- 为图标按钮补齐可访问性标签（优先 `Label(...).labelStyle(.iconOnly)`）。
- 将 `KeyEventHandlingView` 改为“返回是否处理”的事件分发：处理则拦截；未处理则 `super.keyDown(with:)` 让系统键盘导航（Tab/Shift-Tab 等）正常工作。
- 统一两种面板的键盘事件解析逻辑到一个可测试的 `PanelKeyCommand` 解释器。
- `ToastPresenter` 展示时补发 `NSAccessibility` announcement（VoiceOver 可听到提示）。
- 剪贴板侧：给 `Timer` 设置 `tolerance`、`SystemPasteboardClient.readSnapshot()` 按需读取数据、`ClipboardStore.trimToMaxCount()` 用偏移/批量方式删除，保持现有语义并补回归测试。

**Tech Stack:** Swift 5, SwiftUI, AppKit, SwiftData, XCTest, `xcodebuildmcp`, `xcp`

---

## 预检（建议在独立 worktree 执行）

### Task 0: 创建 worktree 与分支（可选但推荐）

**Files:**
- None

**Step 1: 创建新分支与 worktree**

Run:
```bash
git fetch --all
git worktree add ../quicker-a11y-keyboard-perf -b codex/a11y-keyboard-perf
cd ../quicker-a11y-keyboard-perf
```

Expected:
- 新目录存在且可进入
- `git status --porcelain` 输出为空

**Step 2: 确认工程存在**

Run:
```bash
ls -la quicker.xcodeproj
```

Expected:
- `quicker.xcodeproj` 存在

---

## XcodeBuildMCP 初始化（必须）

> 约束：构建/测试优先使用 `xcodebuildmcp`。如遇到 MCP/daemon 异常，再按 `axiom-xcode-debugging` 做环境排查或临时回退 `xcodebuild`。

### Task 0b: 确认 schemes 与基础测试可跑

**Files:**
- None

**Step 1: 发现工程**

Run:
```bash
xcodebuildmcp macos discover-projects --workspace-root .
```

Expected:
- 输出包含 `quicker.xcodeproj`

**Step 2: 列出 schemes**

Run:
```bash
xcodebuildmcp macos list-schemes --project-path ./quicker.xcodeproj
```

Expected:
- 输出包含 `quicker`

**Step 3: 跑一个快的基线测试集**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/ClipboardStoreTests \
  -only-testing:quickerTests/ClipboardStoreImageTests \
  -only-testing:quickerTests/PasteboardCaptureLogicTests
```

Expected:
- PASS

If FAIL（环境优先排查，2–5 分钟内能解决的那种）:
- `ps aux | grep -E "xcodebuild|Xcode|Simulator" | grep -v grep`
- `du -sh ~/Library/Developer/Xcode/DerivedData`
- 必要时清理 DerivedData 后重试

---

## A11y + 键盘导航（高优先级）

### Task 1: 为面板键盘事件解释器写回归测试（先锁定行为）

**Files:**
- Create: `quickerTests/PanelKeyCommandTests.swift`

**Step 1: 写测试（当前会 FAIL，因为实现不存在）**

Create `quickerTests/PanelKeyCommandTests.swift`:
```swift
import XCTest
@testable import quicker

final class PanelKeyCommandTests: XCTestCase {
    func testEscCloses() {
        let cmd = PanelKeyCommand.interpret(.init(keyCode: 53), pageSize: 5)
        XCTAssertEqual(cmd, .close)
    }

    func testReturnConfirms() {
        let cmd = PanelKeyCommand.interpret(.init(keyCode: 36), pageSize: 5)
        XCTAssertEqual(cmd, .confirm)
    }

    func testArrowKeys() {
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 126), pageSize: 5), .moveUp)
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 125), pageSize: 5), .moveDown)
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 123), pageSize: 5), .previousPage)
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 124), pageSize: 5), .nextPage)
    }

    func testCmdCommaOpensSettings() {
        let cmd = PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: ",", isCommandDown: true), pageSize: 5)
        XCTAssertEqual(cmd, .openSettings)
    }

    func testCmdNumberPastesWithinPageSize() {
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: "1", isCommandDown: true), pageSize: 5), .pasteCmdNumber(1))
        XCTAssertEqual(PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: "5", isCommandDown: true), pageSize: 5), .pasteCmdNumber(5))
        XCTAssertNil(PanelKeyCommand.interpret(.init(keyCode: 0, charactersIgnoringModifiers: "6", isCommandDown: true), pageSize: 5))
    }

    func testUnhandledReturnsNil() {
        XCTAssertNil(PanelKeyCommand.interpret(.init(keyCode: 48), pageSize: 5)) // Tab
    }
}
```

**Step 2: 跑测试确认失败**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/PanelKeyCommandTests
```

Expected:
- FAIL（`PanelKeyCommand` 未定义）

---

### Task 2: 实现 `PanelKeyCommand`（让 Task 1 通过）

**Files:**
- Create: `quicker/Panel/PanelKeyCommand.swift`

**Step 1: 最小实现（仅满足测试）**

Create `quicker/Panel/PanelKeyCommand.swift`:
```swift
import Foundation

struct PanelKeyEvent: Equatable {
    let keyCode: UInt16
    let charactersIgnoringModifiers: String?
    let isCommandDown: Bool

    init(keyCode: UInt16, charactersIgnoringModifiers: String? = nil, isCommandDown: Bool = false) {
        self.keyCode = keyCode
        self.charactersIgnoringModifiers = charactersIgnoringModifiers
        self.isCommandDown = isCommandDown
    }
}

enum PanelKeyCommand: Equatable {
    case close
    case openSettings
    case confirm
    case moveUp
    case moveDown
    case previousPage
    case nextPage
    case pasteCmdNumber(Int)

    static func interpret(_ event: PanelKeyEvent, pageSize: Int) -> PanelKeyCommand? {
        if event.keyCode == 53 { return .close } // Esc
        if event.isCommandDown, event.charactersIgnoringModifiers == "," { return .openSettings }
        if event.keyCode == 36 { return .confirm } // Return

        switch event.keyCode {
        case 126: return .moveUp
        case 125: return .moveDown
        case 123: return .previousPage
        case 124: return .nextPage
        default: break
        }

        if event.isCommandDown,
           let raw = event.charactersIgnoringModifiers,
           let number = Int(raw),
           (1...pageSize).contains(number) {
            return .pasteCmdNumber(number)
        }

        return nil
    }
}
```

**Step 2: 跑测试确认通过**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/PanelKeyCommandTests
```

Expected:
- PASS

**Step 3: Commit**

Run:
```bash
git add quicker/Panel/PanelKeyCommand.swift quickerTests/PanelKeyCommandTests.swift
git commit -m "feat(panel): 新增面板按键解释器与测试"
```

---

### Task 3: 让 `KeyEventHandlingView` 支持“未处理交给系统”（解决按键被吞）

**Files:**
- Modify: `quicker/Panel/KeyEventHandlingView.swift`
- Modify: `quicker/Panel/ClipboardPanelView.swift`
- Modify: `quicker/TextBlock/TextBlockPanelView.swift`

**Step 1: 调整 `KeyEventHandlingView` 签名（返回 Bool）**

在 `quicker/Panel/KeyEventHandlingView.swift` 把：
```swift
var onKeyDown: (NSEvent) -> Void
```
改为：
```swift
var onKeyDown: (NSEvent) -> Bool
```

并在 `KeyCatcherView.keyDown(with:)` 里改为：
```swift
override func keyDown(with event: NSEvent) {
    let handled = onKeyDown?(event) ?? false
    if handled { return }
    super.keyDown(with: event)
}
```

**Step 2: 在 `ClipboardPanelView` 把 `handleKeyDown` 改为返回 Bool 并用解释器**

在 `quicker/Panel/ClipboardPanelView.swift` 把：
```swift
KeyEventHandlingView { event in
    handleKeyDown(event)
}
```
改为：
```swift
KeyEventHandlingView { event in
    handleKeyDown(event)
}
```
（保持调用形式不变，但 `handleKeyDown` 改为 `-> Bool`）

将 `private func handleKeyDown(_ event: NSEvent)` 改为 `private func handleKeyDown(_ event: NSEvent) -> Bool`，并用：
```swift
let cmd = PanelKeyCommand.interpret(
    .init(
        keyCode: UInt16(event.keyCode),
        charactersIgnoringModifiers: event.charactersIgnoringModifiers,
        isCommandDown: event.modifierFlags.contains(.command)
    ),
    pageSize: viewModel.pageSize
)
```
来 `switch cmd`，每个分支处理后 `return true`，默认 `return false`。

**Step 3: 同步修改 `TextBlockPanelView`**

在 `quicker/TextBlock/TextBlockPanelView.swift` 同样把 `handleKeyDown` 改为 `-> Bool` 并使用 `PanelKeyCommand`。

**Step 4: 跑相关测试（至少编译 + 解释器测试）**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/PanelKeyCommandTests
```

Expected:
- PASS（至少保证新类型可见、编译无误）

**Step 5: 手动验证（键盘导航）**

- 打开剪贴板面板：确认方向键/Enter/Esc 仍可用
- 按 `Tab`：不应被完全吞（系统可选择发出提示音或切换焦点，关键是我们的拦截逻辑不应强行吃掉）

**Step 6: Commit**

Run:
```bash
git add quicker/Panel/KeyEventHandlingView.swift quicker/Panel/ClipboardPanelView.swift quicker/TextBlock/TextBlockPanelView.swift
git commit -m "fix(panel): 未处理按键交由系统处理"
```

---

### Task 4: 把面板行点击从 `.onTapGesture` 改为语义化 `Button`（VoiceOver/键盘更友好）

**Files:**
- Modify: `quicker/Panel/ClipboardPanelView.swift`
- Modify: `quicker/TextBlock/TextBlockPanelView.swift`

**Step 1: `ClipboardEntryRow` 改为 `Button`（避免 `.onTapGesture`）**

在 `quicker/Panel/ClipboardPanelView.swift` 的 `ClipboardEntryRow` 把：
```swift
.onTapGesture { onSelect() }
```
改为用 `Button(action:)` 包裹整行，并添加：
- `.buttonStyle(.plain)`
- `.accessibilityAddTraits(isSelected ? [.isSelected] : [])`

示例（可直接粘贴调整）：
```swift
Button(action: onSelect) {
    HStack(spacing: 10) {
        // 原 leading + 文本布局
    }
}
.buttonStyle(.plain)
```

**Step 2: `TextBlockPanelView` 列表行改为 `Button`**

在 `quicker/TextBlock/TextBlockPanelView.swift` 的条目视图把：
```swift
.onTapGesture { viewModel.selectIndexInPage(idx) }
```
改为：
```swift
Button { viewModel.selectIndexInPage(idx) } label: {
    // 原 VStack 内容
}
.buttonStyle(.plain)
```

**Step 3: 运行一次编译/测试**

Run:
```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected:
- BUILD SUCCEEDED

**Step 4: 手动验证（VoiceOver）**

- VoiceOver 聚焦列表行时，应更像“按钮/可按下元素”
- 选中行应能被读出（`isSelected` trait）

**Step 5: Commit**

Run:
```bash
git add quicker/Panel/ClipboardPanelView.swift quicker/TextBlock/TextBlockPanelView.swift
git commit -m "fix(a11y): 面板列表行使用按钮语义"
```

---

### Task 5: 给设置页的图标按钮补齐可访问性标签（避免仅靠 `.help`）

**Files:**
- Modify: `quicker/Settings/TextBlockSettingsView.swift`
- Modify: `quicker/Settings/ClipboardSettingsView.swift`

**Step 1: 把 `Image(systemName:)` 按钮标签改为 `Label(...).labelStyle(.iconOnly)`**

目标位置示例：
- `quicker/Settings/TextBlockSettingsView.swift`（上移/下移、编辑/删除）
- `quicker/Settings/ClipboardSettingsView.swift`（移除忽略应用）

示例：
```swift
Button(action: moveUp) {
    Label("上移", systemImage: "arrow.up")
        .labelStyle(.iconOnly)
}
```

**Step 2: 运行编译**

Run:
```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected:
- BUILD SUCCEEDED

**Step 3: Commit**

Run:
```bash
git add quicker/Settings/TextBlockSettingsView.swift quicker/Settings/ClipboardSettingsView.swift
git commit -m "fix(a11y): 设置页图标按钮补齐标签"
```

---

### Task 6: `TextBlockListCard` 增强 VoiceOver 语义（避免嵌套 Button 的大改动）

**Files:**
- Modify: `quicker/Settings/TextBlockSettingsView.swift`

**Step 1: 为卡片添加可访问性 press action + selected trait**

在 `TextBlockListCard` 根视图的 modifier 区域增加：
- `.accessibilityElement(children: .combine)`
- `.accessibilityAddTraits(.isButton)`
- `.accessibilityAddTraits(isSelected ? [.isSelected] : [])`
- `.accessibilityAction(.press, onSelect)`

**Step 2: 手动验证（VoiceOver）**

- VoiceOver 聚焦卡片时，能“按下”触发选择
- 编辑/删除两个按钮仍可单独聚焦与触发

**Step 3: Commit**

Run:
```bash
git add quicker/Settings/TextBlockSettingsView.swift
git commit -m "fix(a11y): 文本块卡片支持按下与选中语义"
```

---

## Toast VoiceOver 提示（中优先级）

### Task 7: `ToastPresenter` 发出 VoiceOver announcement

**Files:**
- Modify: `quicker/UI/ToastPresenter.swift`

**Step 1: 在 `show(message:duration:)` 展示后 post announcement**

在 `panel.orderFrontRegardless()` 后追加：
```swift
NSAccessibility.post(
    element: NSApp as Any,
    notification: .announcementRequested,
    userInfo: [.announcement: message]
)
```

**Step 2: 编译**

Run:
```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected:
- BUILD SUCCEEDED

**Step 3: 手动验证**

- 开启 VoiceOver
- 触发一个会 `toast.show(...)` 的场景，确认能听到播报

**Step 4: Commit**

Run:
```bash
git add quicker/UI/ToastPresenter.swift
git commit -m "fix(ui): toast 增加 VoiceOver 播报"
```

---

## 剪贴板性能与能耗（中/低优先级，但长期收益）

### Task 8: `ClipboardMonitor` 降低轮询抖动/能耗

**Files:**
- Modify: `quicker/Clipboard/ClipboardMonitor.swift`

**Step 1: 给 `Timer` 设置 `tolerance`**

在 `start(pollInterval:)` 创建 timer 后追加：
```swift
timer?.tolerance = pollInterval * 0.15
```

**Step 2: 跑相关测试**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/ClipboardMonitorLogicTests \
  -only-testing:quickerTests/ClipboardMonitorIntegrationStyleTests
```

Expected:
- PASS

**Step 3: Commit**

Run:
```bash
git add quicker/Clipboard/ClipboardMonitor.swift
git commit -m "perf(clipboard): 轮询 timer 设置容忍度"
```

---

### Task 9: `SystemPasteboardClient.readSnapshot()` 按需读取类型数据

**Files:**
- Modify: `quicker/Clipboard/PasteboardClient.swift`

**Step 1: 仅在存在对应类型时才读取 data/string**

思路（示例）：
```swift
let types = item.types
let hasPNG = types.contains(.png)
let pngData = hasPNG ? item.data(forType: .png) : nil
```

**Step 2: 跑 `PasteboardCaptureLogic` 相关测试**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/PasteboardCaptureLogicTests \
  -only-testing:quickerTests/PasteboardCaptureLogicImageTests
```

Expected:
- PASS

**Step 3: Commit**

Run:
```bash
git add quicker/Clipboard/PasteboardClient.swift
git commit -m "perf(clipboard): 按需读取 pasteboard 数据"
```

---

### Task 10: 优化 `ClipboardStore.trimToMaxCount()`（批量/偏移删除）并补回归测试

**Files:**
- Modify: `quicker/Clipboard/ClipboardStore.swift`
- Modify: `quickerTests/ClipboardStoreImageTests.swift`

**Step 1: 先加回归测试（可能 PASS；目的是防回归）**

在 `quickerTests/ClipboardStoreImageTests.swift` 追加：
```swift
func testMaxHistoryCountTrimsImageAndDeletesFile() throws {
    let schema = Schema([ClipboardEntry.self])
    let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [config])

    let baseURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let assets = ClipboardAssetStore(baseURL: baseURL)

    let defaults = UserDefaults(suiteName: UUID().uuidString)!
    let prefs = PreferencesStore(userDefaults: defaults)
    prefs.maxHistoryCount = 1
    prefs.dedupeAdjacentEnabled = false

    let store = ClipboardStore(modelContainer: container, preferences: prefs, assetStore: assets)

    let png1 = Data([0x01])
    let hash1 = ContentHash.sha256Hex(png1)
    _ = try store.insertImage(pngData: png1, contentHash: hash1)
    let rel1 = "\(hash1).png"
    XCTAssertTrue(FileManager.default.fileExists(atPath: assets.fileURL(relativePath: rel1).path))

    let png2 = Data([0x02])
    let hash2 = ContentHash.sha256Hex(png2)
    _ = try store.insertImage(pngData: png2, contentHash: hash2)

    let latest = try store.fetchLatest(limit: 10)
    XCTAssertEqual(latest.count, 1)
    XCTAssertEqual(latest.first?.contentHash, hash2)
    XCTAssertFalse(FileManager.default.fileExists(atPath: assets.fileURL(relativePath: rel1).path))
}
```

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/ClipboardStoreImageTests
```

Expected:
- PASS

**Step 2: 在 `ClipboardStore` 增加支持 offset/batch 的 fetch**

在 `quicker/Clipboard/ClipboardStore.swift` 增加新方法：
```swift
func fetchLatest(offset: Int, limit: Int) throws -> [ClipboardEntry] {
    var descriptor = FetchDescriptor<ClipboardEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    descriptor.fetchOffset = offset
    descriptor.fetchLimit = limit
    return try context.fetch(descriptor)
}
```

**Step 3: 改造 `trimToMaxCount()` 为循环批量删除**

策略：
- 先 `fetchLatest(limit: maxCount)` 得到 `keptImagePaths`
- 反复 `fetchLatest(offset: maxCount, limit: 200)`，直到为空
- 每批删除后 `context.save()`（或收集后一次 save；优先最小改动、易审查）
- 删除图片文件时仍用 `deleteImagePaths.subtracting(keptImagePaths)`，保证不会误删仍被保留的文件

**Step 4: 跑相关测试**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args \
  -only-testing:quickerTests/ClipboardStoreTests \
  -only-testing:quickerTests/ClipboardStoreImageTests
```

Expected:
- PASS

**Step 5: Commit**

Run:
```bash
git add quicker/Clipboard/ClipboardStore.swift quickerTests/ClipboardStoreImageTests.swift
git commit -m "perf(clipboard): 历史裁剪使用批量删除"
```

---

## 收尾验证

### Task 11: 跑一遍更完整的测试集

**Files:**
- None

**Step 1: 跑 quickerTests（全量）**

Run:
```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker
```

Expected:
- PASS

**Step 2: 手动回归（5 分钟）**

- 打开剪贴板面板/文本块面板：方向键/翻页/回车/ESC 正常
- VoiceOver：面板列表行更像可按下元素；toast 可播报
- 连续复制大量内容：应用无明显卡顿/CPU 异常

