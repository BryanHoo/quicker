# 剪贴板历史面板与文本块面板：双击条目执行粘贴/插入（设计文档）

状态：定稿（已确认）

日期：2026-02-25

## 背景

当前 `ClipboardPanelView`（剪贴板历史面板）与 `TextBlockPanelView`（文本块面板）均支持通过键盘 `Enter` 或 `⌘数字` 对选中条目执行“粘贴/插入”。鼠标点击条目目前只会更新选中态，不会触发粘贴/插入。

用户希望在两类面板中支持通过鼠标快速触发对应条目的粘贴/插入。

## 目标

- 在剪贴板历史面板与文本块面板中支持：**双击条目立即执行粘贴/插入并关闭面板**。
- 保持现有键盘快捷键行为不变（`Enter`/`⌘数字` 等）。
- 保持单击条目的行为不变：**单击只选中，不触发粘贴/插入**。

## 非目标

- 不新增额外的 UI 文案提示（footer / 行内提示）。
- 不新增/调整任何持久化结构与存储逻辑。
- 不改变粘贴权限判定、回切前台应用、以及失败时“仅复制”的行为语义。

## 现状（代码位置）

- 剪贴板历史面板：
  - UI：`quicker/Panel/ClipboardPanelView.swift`
  - 粘贴入口（由 controller 传入）：`ClipboardPanelView(onPaste:)`
  - 关闭 + 回切 + 粘贴：`quicker/Panel/PanelController.swift`、`quicker/App/AppState.swift`（`pasteClipboardEntry`）
- 文本块面板：
  - UI：`quicker/TextBlock/TextBlockPanelView.swift`
  - 插入入口（由 controller 传入）：`TextBlockPanelView(onInsert:)`
  - 关闭 + 回切 + 粘贴：`quicker/TextBlock/TextBlockPanelController.swift`、`quicker/App/AppState.swift`（`pasteTextBlockEntry`）

## 方案概述（已选定）

采用 **方案 1：SwiftUI 双击手势**。

- 保留列表行作为语义化 `Button`（既有可访问性与交互基础）。
- 在行上额外添加 `TapGesture(count: 2)`（建议用 `simultaneousGesture`），在双击时触发 `onPaste(entry)` / `onInsert(entry)`。

## 交互设计

### 剪贴板历史面板

- 单击条目：只选中（保持现状）。
- 双击条目：触发 `onPaste(entry)`；面板关闭并按既有逻辑执行粘贴（或仅复制）。

### 文本块面板

- 单击条目：只选中（保持现状）。
- 双击条目：触发 `onInsert(entry)`；面板关闭并按既有逻辑执行粘贴（或仅复制）。

## 数据流与行为一致性

双击触发不引入新的粘贴路径，复用现有 controller → `AppState` 的流程：

- `PanelController` / `TextBlockPanelController` 在触发回调时先关闭面板并传入 `previousFrontmostApp`。
- `AppState.pasteClipboardEntry` / `AppState.pasteTextBlockEntry` 继续承担：
  - 辅助功能权限检查（必要时提示）
  - 回切到 `previousFrontmostApp`
  - 延迟触发自动粘贴（或退化为仅复制）
  - 权限状态转换时的重启提示（如有）

因此双击与 `Enter`/`⌘数字` 的行为保持一致，仅新增一种“触发入口”。

## 实现要点

- `ClipboardPanelView`：
  - 在 `ClipboardEntryRow`（或行的外层 `Button`）上增加双击手势，在识别到双击时调用上层 `onPaste(entry)`。
- `TextBlockPanelView`：
  - 在每行条目的 `Button` 上增加双击手势，在识别到双击时调用上层 `onInsert(entry)`。
- 采用 SwiftUI 手势实现，避免引入 AppKit `NSClickGestureRecognizer` 桥接与维护成本。
- 双击包含两次单击：预期会先更新选中态，然后执行一次粘贴/插入；不影响最终行为。

## 测试计划

由于双击手势属于 UI 行为，优先手动验证；不强制新增 XCTest：

- 手动验证：
  1. 打开剪贴板历史面板：单击仅选中；双击触发粘贴并关闭面板。
  2. 打开文本块面板：单击仅选中；双击触发插入并关闭面板。
  3. 回归键盘行为：`Enter` 与 `⌘数字` 仍可用，行为不变。
  4. 在未授予辅助功能权限时：双击应退化为仅复制（并保持既有提示/行为）。

## 风险与回滚

风险：
- 双击会先触发单击（选中），但预期不产生副作用；需确保双击只触发一次粘贴/插入。
- 触控板/鼠标双击速度由系统设置决定；无需在应用内自定义阈值。

回滚：
- 删除两处面板行的双击手势即可，改动集中且易回退。

