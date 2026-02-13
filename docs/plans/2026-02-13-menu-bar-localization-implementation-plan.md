# 菜单栏菜单简体中文化 Implementation Plan

> **For AI:** REQUIRED SUB-SKILL: Use workflow-executing-plans to implement this plan task-by-task.

**Goal:** 将菜单栏图标点击弹出的 `MenuBarExtra` 菜单文案从英文改为简体中文，并用单测防止回归。

**Architecture:** 继续沿用项目当前“直接写中文文案”的策略（不引入 `Localizable.strings` / `.xcstrings` 的多语言框架），仅把 `quicker/quickerApp.swift` 中的英文 `Button` / `SettingsLink` 文案替换为中文；通过一个轻量 XCTest 读取源文件并断言不包含特定英文文案，确保后续改动不会把菜单文案改回英文。

**Tech Stack:** SwiftUI（`MenuBarExtra` / `SettingsLink`）、XCTest、`xcodebuildmcp`

---

### Task 1: 为菜单栏菜单英文文案写回归测试，并翻译为简体中文

**Files:**

- Create: `quickerTests/MenuBarLocalizationTests.swift`
- Modify: `quicker/quickerApp.swift`

**Step 1: Write the failing test**

在 `quickerTests/MenuBarLocalizationTests.swift` 新增测试，读取 `quicker/quickerApp.swift` 源码并断言：

- 不应再出现这些英文菜单文案：
  - `Open Clipboard Panel`
  - `Open Text Block Panel`
  - `Settings…`
  - `Clear History`
  - `Quit`
- 应出现对应中文文案（用于防止“删掉按钮但没替换文案”的假阳性）：
  - `打开剪贴板面板`
  - `打开文本块面板`
  - `偏好设置…`
  - `清空历史`
  - `退出`

建议测试实现（保持最小可用即可）：

```swift
import XCTest
@testable import quicker

final class MenuBarLocalizationTests: XCTestCase {
    func testMenuBarExtraMenuIsSimplifiedChinese() throws {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let projectRoot = testFileURL.deletingLastPathComponent().deletingLastPathComponent()
        let appFileURL = projectRoot.appendingPathComponent("quicker/quickerApp.swift")

        let source = try String(contentsOf: appFileURL, encoding: .utf8)

        XCTAssertFalse(source.contains("Open Clipboard Panel"))
        XCTAssertFalse(source.contains("Open Text Block Panel"))
        XCTAssertFalse(source.contains("Settings…"))
        XCTAssertFalse(source.contains("Clear History"))
        XCTAssertFalse(source.contains("Quit"))

        XCTAssertTrue(source.contains("打开剪贴板面板"))
        XCTAssertTrue(source.contains("打开文本块面板"))
        XCTAssertTrue(source.contains("偏好设置…"))
        XCTAssertTrue(source.contains("清空历史"))
        XCTAssertTrue(source.contains("退出"))
    }
}
```

**Step 2: Run test to verify it fails**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args=-only-testing:quickerTests/MenuBarLocalizationTests
```

Expected: FAIL（断言失败），错误信息包含类似 `XCTAssertFalse failed`，并指向仍存在的英文文案（例如 `Open Clipboard Panel`）。

**Step 3: Write minimal implementation**

在 `quicker/quickerApp.swift` 将 `MenuBarExtra` 内的英文文案替换为简体中文（保持功能不变，仅改文案）：

- `Button("Open Clipboard Panel")` → `Button("打开剪贴板面板")`
- `Button("Open Text Block Panel")` → `Button("打开文本块面板")`
- `SettingsLink { Text("Settings…") }` → `SettingsLink { Text("偏好设置…") }`
- `Button("Clear History")` → `Button("清空历史")`
- `Button("Quit")` → `Button("退出")`

备注（本任务不做但需避免误改）：
- `Image(systemName: "bolt.fill")` 里的 `"bolt.fill"` 是 SF Symbols 名称，不要翻译。
- `NSApp.terminate(nil)` 逻辑不变。

**Step 4: Run test to verify it passes**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args=-only-testing:quickerTests/MenuBarLocalizationTests
```

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/quickerApp.swift quickerTests/MenuBarLocalizationTests.swift
git commit -m "fix(app): 菜单栏菜单文案改为中文"
```

---

### 手动验收（建议）

1. 构建并运行：

```bash
xcodebuildmcp macos build-and-run --project-path ./quicker.xcodeproj --scheme quicker
```

2. 点击菜单栏图标，确认菜单项显示为：
   - 打开剪贴板面板
   - 打开文本块面板
   - 偏好设置…
   - 清空历史
   - 退出
