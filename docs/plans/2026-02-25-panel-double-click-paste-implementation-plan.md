# 面板双击粘贴/插入 Implementation Plan

> **For AI:** REQUIRED SUB-SKILL: Use workflow-executing-plans to implement this plan task-by-task.

**Goal:** 在 `ClipboardPanelView` 与 `TextBlockPanelView` 中支持“单击选中、双击执行粘贴/插入并关闭面板”，以便用户用鼠标快速触发条目。

**Architecture:** 保持列表行的现有 `Button`（单击只更新选中态），在行上增加 SwiftUI `TapGesture(count: 2)`（建议用 `simultaneousGesture`）在双击时调用现有 `onPaste(entry)` / `onInsert(entry)` 回调；粘贴路径完全复用现有 controller → `AppState` 的逻辑（权限判断、回切前台应用、自动粘贴/仅复制语义不变）。

**Tech Stack:** Swift 5 / SwiftUI / AppKit (`NSPanel`, `NSWindowDelegate`) / XCTest / `xcodebuildmcp`

---

## Prior Art

- 设计文档（已确认）：`docs/plans/2026-02-25-panel-double-click-paste-design.md`
- 面板相关代码：
  - 剪贴板面板：`quicker/Panel/ClipboardPanelView.swift`、`quicker/Panel/PanelController.swift`
  - 文本块面板：`quicker/TextBlock/TextBlockPanelView.swift`、`quicker/TextBlock/TextBlockPanelController.swift`
  - 粘贴/插入入口：`quicker/App/AppState.swift`（`pasteClipboardEntry` / `pasteTextBlockEntry`）

## Inputs (Call Chains)

- 剪贴板面板双击触发后最终走到：
  - `ClipboardPanelView(onPaste:)`
  - `PanelController.makePanel()` 中的 `onPaste` closure（会先 `close()`，再调用 `AppState.pasteClipboardEntry`）
  - `AppState.pasteClipboardEntry` → `pasteService.paste(entry:)`
- 文本块面板双击触发后最终走到：
  - `TextBlockPanelView(onInsert:)`
  - `TextBlockPanelController.makePanel()` 中的 `onInsert` closure（会先 `close()`，再调用 `AppState.pasteTextBlockEntry`）
  - `AppState.pasteTextBlockEntry` → `pasteService.paste(text:)`

## Risks / Pitfalls (Read Before Coding)

- SwiftUI `Button` + 双击手势可能存在事件竞争：优先使用 `.simultaneousGesture(TapGesture(count: 2))`，必要时再考虑 `.highPriorityGesture` 作为兜底。
- 双击包含两次单击：预期会先更新选中态，然后执行一次粘贴/插入；需要确保双击不会导致重复触发粘贴/插入。
- 体验风险：如果双击手势导致单击选中出现延迟，需要回退/调整手势挂载方式（例如把手势挂在行外层，而不是 label 内层）。
- 权限/回切行为必须保持一致：双击只新增“触发入口”，不得绕过 `AppState.pasteClipboardEntry` / `AppState.pasteTextBlockEntry`。
- 面板为 `.nonactivatingPanel`：双击触发后会切回 `previousFrontmostApp`，需手动确认没有“粘贴到错误窗口”的回归。

---

### Task 1: Create Worktree (Recommended)

**Files:**

- None

**Step 1: Verify `.worktrees/` is ignored**

Run:

```bash
git check-ignore -q .worktrees && echo "OK: .worktrees ignored"
```

Expected: 输出 `OK: .worktrees ignored`。

**Step 2: Create a dedicated branch + worktree**

Run:

```bash
git worktree add -b codex/panel-double-click-paste .worktrees/panel-double-click-paste
```

Expected: 创建新目录 `.worktrees/panel-double-click-paste`，并检出到新分支 `codex/panel-double-click-paste`。

**Step 3: Verify status**

Run:

```bash
cd .worktrees/panel-double-click-paste && git status --porcelain
```

Expected: no output (clean)。

**Step 4: Baseline tests (optional but recommended)**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker
```

Expected: 测试通过（如有既有 skip，按基线一致即可）。

---

### Task 2: Clipboard Panel — Double Click to Paste

**Files:**

- Modify: `quicker/Panel/ClipboardPanelView.swift:145`

**Step 1: Implement double-click gesture on row**

在 `ForEach` 渲染 `ClipboardEntryRow(...)` 的位置，给每行增加双击手势（保持单击仍只选中）：

```swift
ClipboardEntryRow(
    entry: entry,
    cmdNumber: idx + 1,
    isSelected: idx == viewModel.selectedIndexInPage,
    onSelect: {
        viewModel.selectIndexInPage(idx)
    }
)
.simultaneousGesture(
    TapGesture(count: 2).onEnded {
        onPaste(entry)
    }
)
```

Notes:
- 使用 `simultaneousGesture` 是为了尽量不破坏 `Button` 的单击选中行为。
- 这里直接使用 `entry` 调用 `onPaste(entry)`，避免依赖 `viewModel.selectedEntry`（双击时目标应为被双击的那一行）。

**Step 2: Build**

Run:

```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected: `BUILD SUCCEEDED`。

**Step 3: Run unit tests**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker
```

Expected: tests passed（如有既有 skip，按基线一致即可）。

**Step 4: Manual verification (Clipboard Panel)**

- 打开剪贴板面板（快捷键进入）。
- 单击任意条目：只改变高亮选中，不粘贴、不关闭。
- 双击任意条目：面板关闭，并对外执行粘贴（若未授权辅助功能权限则应退化为仅复制）。

**Step 5: Commit**

```bash
git add quicker/Panel/ClipboardPanelView.swift
git commit -m "feat(panel): 剪贴板面板支持双击粘贴"
```

---

### Task 3: Text Block Panel — Double Click to Insert

**Files:**

- Modify: `quicker/TextBlock/TextBlockPanelView.swift:112`

**Step 1: Implement double-click gesture on row**

在文本块列表行的 `Button` 上追加双击手势（保持单击仍只选中）：

```swift
Button { viewModel.selectIndexInPage(idx) } label: {
    // existing row UI
}
.buttonStyle(.plain)
.simultaneousGesture(
    TapGesture(count: 2).onEnded {
        onInsert(entry)
    }
)
```

Notes:
- 同样使用 `entry` 作为双击目标，避免依赖 `selectedEntry`。

**Step 2: Build**

Run:

```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected: `BUILD SUCCEEDED`。

**Step 3: Run unit tests**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker
```

Expected: tests passed（如有既有 skip，按基线一致即可）。

**Step 4: Manual verification (Text Block Panel)**

- 打开文本块面板（快捷键进入）。
- 单击任意条目：只改变选中，不插入、不关闭。
- 双击任意条目：面板关闭，并对外执行插入/粘贴（若未授权辅助功能权限则应退化为仅复制）。

**Step 5: Commit**

```bash
git add quicker/TextBlock/TextBlockPanelView.swift
git commit -m "feat(panel): 文本块面板支持双击插入"
```

---

### Task 4: Final Regression Checklist

**Files:**

- None

**Step 1: Keyboard regression**

手动确认两面板仍支持：
- `Enter` 执行粘贴/插入
- `⌘数字` 执行对应条目粘贴/插入
- `Esc` 关闭
- `↑↓/←→` 导航与翻页

**Step 2: Paste semantics regression**

手动确认双击触发与 `Enter` 触发在以下方面一致：
- 有辅助功能权限：应自动粘贴到 `previousFrontmostApp`
- 无辅助功能权限：应仅复制（不自动粘贴）

