# Settings Panel Window Chrome Implementation Plan

> **For AI:** REQUIRED SUB-SKILL: Use workflow-executing-plans to implement this plan task-by-task.

**Goal:** 移除设置面板外层系统窗口的“原生框架/边框感”，让 `SettingsView` 的自绘面板成为窗口主要视觉，同时保留左上角可点击关闭（系统 close button）。

**Architecture:** 在 `SettingsView` 中注入一个轻量的 `NSViewRepresentable`（window configurator），在 `viewDidMoveToWindow()` 时拿到 `NSWindow` 并应用统一的 `SettingsWindowStyle.apply(to:)`。把 window 样式设置封装为可单测的纯函数入口；UI 侧仅做少量 layout 调整避免 titlebar buttons 覆盖内容。

**Tech Stack:** Swift 5 / SwiftUI / AppKit / XCTest / `xcodebuildmcp`

---

## Prior Art

- 需要确保本改动不回归“设置窗口弹出但在别的应用下面”的问题：`docs/solutions/integration-issues/settings-window-behind-other-apps.md`（当前通过 `NSApp.activate(ignoringOtherApps: true)` + `openSettings()` 解决）。

---

### Task 1: Create Worktree (Recommended)

**Files:**

- None

**Step 1: Create a dedicated branch + worktree**

Run:

```bash
git worktree add -b codex/settings-window-chrome ../quicker-settings-window-chrome
```

Expected: 创建新目录 `../quicker-settings-window-chrome`，并切到新分支 `codex/settings-window-chrome`。

**Step 2: Verify status**

Run:

```bash
cd ../quicker-settings-window-chrome && git status --porcelain
```

Expected: no output (clean)。

---

### Task 2: Add a Failing Unit Test for Window Styling

**Files:**

- Create: `quickerTests/SettingsWindowStyleTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/SettingsWindowStyleTests.swift`:

```swift
import AppKit
import XCTest
@testable import quicker

@MainActor
final class SettingsWindowStyleTests: XCTestCase {
    func testApplyMakesSettingsWindowChromeHiddenButKeepsCloseButton() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        SettingsWindowStyle.apply(to: window)

        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertTrue(window.styleMask.contains(.fullSizeContentView))
        XCTAssertFalse(window.isOpaque)

        XCTAssertEqual(window.backgroundColor?.alphaComponent, 0, accuracy: 0.0001)

        XCTAssertTrue(window.standardWindowButton(.miniaturizeButton)?.isHidden ?? false)
        XCTAssertTrue(window.standardWindowButton(.zoomButton)?.isHidden ?? false)
        XCTAssertFalse(window.standardWindowButton(.closeButton)?.isHidden ?? true)
    }
}
```

**Step 2: Run the test to verify it fails**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/SettingsWindowStyleTests"
```

Expected: FAIL（编译期错误），类似 `Cannot find 'SettingsWindowStyle' in scope`。

---

### Task 3: Implement `SettingsWindowStyle` to Pass the Test

**Files:**

- Create: `quicker/Settings/SettingsWindowStyle.swift`
- Test: `quickerTests/SettingsWindowStyleTests.swift`

**Step 1: Write minimal implementation**

Create `quicker/Settings/SettingsWindowStyle.swift`:

```swift
import AppKit

enum SettingsWindowStyle {
    static func apply(to window: NSWindow) {
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.styleMask.insert(.fullSizeContentView)

        window.isOpaque = false
        window.backgroundColor = .clear

        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.standardWindowButton(.closeButton)?.isHidden = false

        window.isMovableByWindowBackground = true
    }
}
```

**Step 2: Run the test to verify it passes**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/SettingsWindowStyleTests"
```

Expected: PASS（至少该测试类通过）。

**Step 3: Commit**

Run:

```bash
git add quicker/Settings/SettingsWindowStyle.swift quickerTests/SettingsWindowStyleTests.swift
git commit -m "feat(settings): 统一设置窗口无边框样式"
```

---

### Task 4: Add a `SettingsWindowConfigurator` to Apply Style at Runtime

**Files:**

- Create: `quicker/Settings/SettingsWindowConfigurator.swift`

**Step 1: Implement the configurator view**

Create `quicker/Settings/SettingsWindowConfigurator.swift`:

```swift
import AppKit
import SwiftUI

struct SettingsWindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        ConfiguratorView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

private final class ConfiguratorView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        SettingsWindowStyle.apply(to: window)
    }
}
```

**Step 2: Compile quickly**

Run:

```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected: Build succeeded。

**Step 3: Commit**

Run:

```bash
git add quicker/Settings/SettingsWindowConfigurator.swift
git commit -m "feat(settings): 注入窗口配置器应用样式"
```

---

### Task 5: Wire Configurator into `SettingsView` and Remove “Double Frame” Look

**Files:**

- Modify: `quicker/Settings/SettingsView.swift:60`

**Step 1: Inject configurator (no layout impact)**

在 `SettingsView.body` 的根视图 modifier 链末尾追加（建议紧跟 `frame(width:height:)` 之后）：

```swift
.background(SettingsWindowConfigurator())
```

**Step 2: Remove system+custom “double frame”**

将以下两类视觉从“内层卡片”迁移为“窗口本身的 shadow/shape”：

1) 去掉 `SettingsView` 最外层的 `.padding(14)`（避免 panel 被缩在 window 里，导致看起来像“外面还有一层系统框架”）

2) 去掉（或显著减弱）`.shadow(color: palette.windowShadow, radius: 26, x: 0, y: 14)`，让系统 window shadow 接管外部阴影（`SettingsWindowStyle` 不要把 `window.hasShadow` 关掉）。

落地修改（示例，按当前行号）：

- 删除 `quicker/Settings/SettingsView.swift:98` 的 `.shadow(...)`
- 删除 `quicker/Settings/SettingsView.swift:99` 的 `.padding(14)`

**Step 3: Avoid titlebar close button overlapping sidebar header**

因为 `SettingsWindowStyle` 启用了 `.fullSizeContentView`，titlebar buttons 会覆盖到内容区域；将 sidebar/header 的 top padding 增加一档（先以 36 作为起点，之后按视觉回归微调）：

- `quicker/Settings/SettingsView.swift:133`：将 `.padding(.top, 20)` 改为 `.padding(.top, 36)`
- `quicker/Settings/SettingsView.swift:179`：将 `.padding(.top, 20)` 改为 `.padding(.top, 36)`（保持两列头部对齐）

**Step 4: Build & run for manual verification**

Run:

```bash
xcodebuildmcp macos build-and-run --project-path ./quicker.xcodeproj --scheme quicker
```

Manual checks:

- 打开“偏好设置…”后，设置窗口外层不再有系统的明显框架/标题栏背景；窗口视觉以 `SettingsView` 自绘背景/边框为准。
- 左上角 close button 仍可点击关闭。
- sidebar 顶部不被 close button 压住（必要时微调 top padding）。
- 回归验证 `docs/solutions/integration-issues/settings-window-behind-other-apps.md` 的场景：其它应用在前台时，菜单栏点击“偏好设置…”仍能置前显示。

**Step 5: Commit**

Run:

```bash
git add quicker/Settings/SettingsView.swift
git commit -m "fix(settings): 移除设置窗口双层边框观感"
```

---

### Task 6: Run Full Test Suite (Safety Net)

**Files:**

- None

**Step 1: Run all tests**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker
```

Expected: tests passed（允许已有的 skip，例如需要辅助功能权限的 UI tests）。

---

## Done Criteria

- 设置窗口不再呈现“系统窗口框架 + 内层通用面板框架”的叠加观感。
- 左上角 close button 仍然存在且可点击关闭。
- `openSettings()` 置前行为不回归（参考 prior art）。

