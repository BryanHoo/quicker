# Accessibility 无权限系统提示 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 当用户尝试自动粘贴且未授权 Accessibility 时，触发系统自带授权提示（`AXTrustedCheckOptionPrompt`），并移除权限相关的 toast 提示（避免“面板关闭后看不到”）。

**Architecture:** 在粘贴入口 `AppState.pasteClipboardEntry(...)` / `AppState.pasteTextBlockEntry(...)` 进行一次 `permission.isProcessTrusted(promptIfNeeded: true)` 检查：trusted 则激活 `previousApp` 并异步执行粘贴；untrusted 则仅复制到剪贴板。去掉 `ToastPresenter` 在该流程中的依赖与所有 `toast.show(...)` 调用。

**Tech Stack:** Swift 5、AppKit、SwiftUI、XCTest、ApplicationServices（`AXIsProcessTrustedWithOptions`）

---

## Spec / 参考

- 设计文档：`docs/plans/2026-02-11-accessibility-permission-reminder-design.md`

## 预检（建议在独立 worktree 执行）

> 说明：本计划建议在独立 worktree 中执行（减少对当前工作区干扰）。如果你决定直接在当前工作区执行，也可以跳过本任务。

### Task 0: 创建 worktree 与分支（可选但推荐）

**Files:**
- None

**Step 1: 创建新分支与 worktree**

Run（示例路径可自行调整）：
```bash
git fetch --all
git worktree add ../quicker-accessibility-permission-reminder -b codex/accessibility-permission-reminder
cd ../quicker-accessibility-permission-reminder
```

Expected:
- 新目录存在且可进入
- `git status --porcelain` 输出为空

**Step 2: 确认设计文档存在**

Run：
```bash
ls -la docs/plans/2026-02-11-accessibility-permission-reminder-design.md
```

Expected:
- 文件存在（若不存在，先把 `docs/` 相关变更提交/同步到该 worktree）

**Step 3: （可选）打开工程**

Run：
```bash
open quicker.xcodeproj
```

Expected:
- Xcode 正常打开（不作为必须步骤）

**Step 4: Commit（可选）**

如果在此阶段需要把已有 `docs/` 变更纳入分支：
```bash
git add docs/plans/2026-02-11-accessibility-permission-reminder-design.md
git commit -m "docs(app): 记录无权限提示设计"
```

---

## XcodeBuildMCP 初始化（必须）

> 约束：**所有**构建/测试等 Xcode 操作必须通过 XcodeBuildMCP 工具执行，不允许直接调用 `xcodebuild`。

### Task 0b: 设置 XcodeBuildMCP session defaults

**Files:**
- None

**Step 1: 查看当前 defaults（必须先做）**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__session_show_defaults`
- Params: `{}`

Expected:
- 输出当前 defaults（可能为空 `{}`）

**Step 2: 发现工程路径**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__discover_projs`
- Params: `{"workspaceRoot":"<你的工作区根目录>"}`（例如 `/Users/bryanhu/Develop/quicker` 或对应 worktree 目录）

Expected:
- 找到 `quicker.xcodeproj`

**Step 3: 列出 schemes**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__list_schemes`
- Params: `{}`

Expected:
- 至少包含 `quicker`

**Step 4: 设置 defaults（project + scheme + platform）**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__session_set_defaults`
- Params（示例）：
  - `{"projectPath":"<绝对路径>/quicker.xcodeproj","scheme":"quicker","platform":"macOS","configuration":"Debug","persist":false}`

Expected:
- defaults 更新成功

**Step 5: 若缺少 macOS 测试工具，先启用 workflow**

Expected:
- 能够使用 `mcp__XcodeBuildMCP__test_macos` / `mcp__XcodeBuildMCP__build_macos`
- 如果你当前 MCP 客户端只启用了 simulator workflow，需要在 MCP 配置中开启 macOS workflow（或通过 `manage_workflows` 启用），再继续后续测试步骤

---

## TDD：先加测试锁定行为

### Task 1: 为 `promptIfNeeded` 参数写回归测试

**Files:**
- Modify: `quickerTests/PastePreviousAppActivationTests.swift`

**Step 1: 添加可记录参数的 fake permission**

在文件底部的 `FakeAccessibilityPermission` 附近新增（用 `class` 方便记录调用参数）：
```swift
private final class RecordingAccessibilityPermission: AccessibilityPermissionChecking {
    private(set) var lastPromptIfNeeded: Bool?
    private let isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        lastPromptIfNeeded = promptIfNeeded
        return isTrusted
    }
}
```

**Step 2: 写两个失败用例（此时还未改实现，所以应失败）**

在 `PastePreviousAppActivationTests` 内新增：
```swift
func testPasteClipboardEntryChecksAccessibilityPermissionWithPromptEnabled() {
    let pasteService = makePasteService(isTrusted: true)
    let permission = RecordingAccessibilityPermission(isTrusted: true)
    let entry = ClipboardPanelEntry(kind: .text, previewText: "A", createdAt: Date(), rtfData: nil, imagePath: nil, contentHash: "A")

    AppState.pasteClipboardEntry(
        entry,
        previousApp: nil,
        pasteService: pasteService,
        toast: ToastPresenter(),
        permission: permission
    )

    XCTAssertEqual(permission.lastPromptIfNeeded, true)
}

func testPasteTextBlockEntryChecksAccessibilityPermissionWithPromptEnabled() {
    let pasteService = makePasteService(isTrusted: true)
    let permission = RecordingAccessibilityPermission(isTrusted: true)
    let entry = TextBlockPanelEntry(id: UUID(), title: "t", content: "hello")

    AppState.pasteTextBlockEntry(
        entry,
        previousApp: nil,
        pasteService: pasteService,
        toast: ToastPresenter(),
        permission: permission
    )

    XCTAssertEqual(permission.lastPromptIfNeeded, true)
}
```

说明：
- 这里把 `isTrusted` 设为 `true` 是为了避免走到当前实现里的 untrusted 分支触发 `toast.show(...)`（测试环境不应弹 UI）。

**Step 3: 运行测试，确认失败**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__test_macos`
- Params: `{"extraArgs":["-only-testing:quickerTests/PastePreviousAppActivationTests"]}`

Expected:
- FAIL
- 至少包含断言失败：`XCTAssertEqual` 比较 `lastPromptIfNeeded`（当前实现会是 `false`）

**Step 4: Commit（可选）**

此时不建议 commit（因为测试失败）。继续下一任务把实现改到通过后再一起提交。

---

## 实现：触发系统提示 + 移除 toast

### Task 2: 把 `promptIfNeeded` 改为 `true` 让测试通过

**Files:**
- Modify: `quicker/App/AppState.swift`

**Step 1: 修改 `pasteClipboardEntry(...)` 与 `pasteTextBlockEntry(...)` 的权限检查**

将两处：
```swift
permission.isProcessTrusted(promptIfNeeded: false)
```
改为：
```swift
permission.isProcessTrusted(promptIfNeeded: true)
```

**Step 2: 运行测试，确认通过**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__test_macos`
- Params: `{"extraArgs":["-only-testing:quickerTests/PastePreviousAppActivationTests"]}`

Expected:
- PASS

**Step 3: Commit**

Run：
```bash
git add quicker/App/AppState.swift quickerTests/PastePreviousAppActivationTests.swift
git commit -m "fix(app): 触发辅助功能授权提示"
```

---

### Task 3: 移除权限相关 toast（并删除 `ToastPresenter` 参数）

**Files:**
- Modify: `quicker/App/AppState.swift`
- Modify: `quickerTests/PastePreviousAppActivationTests.swift`

**Step 1: `AppState` 两个静态方法移除 `toast` 参数与所有 `toast.show(...)`**

目标形态（以 `pasteClipboardEntry(...)` 为例）：
```swift
static func pasteClipboardEntry(
    _ entry: ClipboardPanelEntry,
    previousApp: RunningApplicationActivating?,
    pasteService: PasteService,
    permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()
) {
    if permission.isProcessTrusted(promptIfNeeded: true) {
        previousApp?.activate(options: [.activateIgnoringOtherApps])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            _ = pasteService.paste(entry: makePasteEntry(from: entry))
        }
    } else {
        _ = pasteService.paste(entry: makePasteEntry(from: entry))
    }
}
```

`pasteTextBlockEntry(...)` 同理：
- 去掉 `toast` 参数
- trusted 分支里直接 `_ = pasteService.paste(text: entry.content)`
- untrusted 分支里直接 `_ = pasteService.paste(text: entry.content)`

注意：
- 保留 `AppState.start()` 中“内存模式”相关的 `toast.show(...)`（与本功能无关）。

**Step 2: 更新 `AppState.init` 里的闭包调用点**

在 `AppState.init()` 中两处：
- `PanelController` 的回调
- `TextBlockPanelController` 的回调

把：
```swift
Self.pasteClipboardEntry(entry, previousApp: previousApp, pasteService: pasteService, toast: toast)
Self.pasteTextBlockEntry(entry, previousApp: previousApp, pasteService: pasteService, toast: toast)
```
更新为移除 `toast: toast` 参数。

**Step 3: 更新测试调用签名**

在 `quickerTests/PastePreviousAppActivationTests.swift`：
- 删除 `let toast = ToastPresenter()`
- 调用 `AppState.pasteClipboardEntry(...)` / `AppState.pasteTextBlockEntry(...)` 时移除 `toast:` 参数
- Task 1 新增的两个测试也同步移除 `toast: ToastPresenter()`

**Step 4: 全局搜索确保没有残留调用**

Run：
```bash
rg -n "toast:" quicker quickerTests
```

Expected:
- 无输出（或仅剩与 `AppState.start()` 无关的地方；理想情况为无）

**Step 5: 跑目标测试**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__test_macos`
- Params: `{"extraArgs":["-only-testing:quickerTests/PastePreviousAppActivationTests","-only-testing:quickerTests/PasteServiceLogicTests"]}`

Expected:
- PASS

**Step 6: Commit**

Run：
```bash
git add quicker/App/AppState.swift quickerTests/PastePreviousAppActivationTests.swift
git commit -m "refactor(app): 移除粘贴降级 toast"
```

---

## 验证与收尾

### Task 4: 回归测试与手动验证

**Files:**
- None

**Step 1: （可选）跑全量单测**

Run（MCP tool）：
- Tool: `mcp__XcodeBuildMCP__test_macos`
- Params: `{}`

Expected:
- PASS（若有与本改动无关的失败，先记录并仅修复与本改动相关的部分）

**Step 2: 手动验证（需要系统环境）**

1. 打开系统设置 → 隐私与安全性 → 辅助功能(Accessibility)，关闭/移除 `quicker` 授权
2. 打开 `quicker`，唤起剪贴板面板/文本块面板，选择一条执行粘贴
3. 期望：出现系统自带授权提示；本次只复制到剪贴板；不出现 toast
4. 在系统设置中开启授权后，回到应用再次触发粘贴
5. 期望：可自动粘贴回原应用（发送 `⌘V`）

**Step 3: 文档（可选）**

若需要对外说明行为变化（不再 toast 提示“已复制，可手动 ⌘V”）：
- 可在 `README.md` 增补一句“未授权时会弹系统提示且仅复制到剪贴板”

---

## 执行交接

计划已写入 `docs/plans/2026-02-11-accessibility-permission-reminder-implementation-plan.md`。两种执行方式：

1. **Subagent-Driven（当前会话）**：我按 Task 逐个执行，每个 Task 完成后你确认再继续（需要 `superpowers:subagent-driven-development`）。
2. **Parallel Session（新会话）**：开新会话并使用 `superpowers:executing-plans` 按本计划逐步执行。

你希望用哪种方式执行？
