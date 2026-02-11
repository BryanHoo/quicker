# Accessibility 无权限提示优化（最小改动）设计文档

状态：草案（待确认）

日期：2026-02-11

## 背景

当前在未授权“辅助功能(Accessibility)”权限时，粘贴逻辑会降级为“仅复制到剪贴板”，并通过 `ToastPresenter` 展示提示文案。但在实际使用中，面板在触发粘贴动作后会立即关闭，同时 `ToastPresenter` 的显示位置与 `NSEvent.mouseLocation` 相关，导致提示很容易被用户错过，从体验上等同于“无提示”。

目标是用**最小改动**让用户在无权限场景下看到**明显的系统级提醒**，并避免引入额外权限（如通知权限）。

## 目标

- 当用户尝试执行粘贴（从剪贴板面板/文本块面板插入）且未获得 Accessibility 权限时，触发系统自带的授权提示（`AXTrustedCheckOptionPrompt`）。
- 去除无权限场景下的 `toast` 提示，避免“提示出现但看不到/来不及看到”的问题。
- 保持现有降级行为：无权限时仍写入剪贴板（用户可手动 `⌘V`）。

## 非目标

- 不实现“授权后自动继续粘贴”的流程（用户完成授权后重新触发一次即可）。
- 不引入 `UNUserNotificationCenter` / 系统通知（避免额外通知权限与配置）。
- 不调整面板关闭时机、窗口层级或 `ToastPresenter` 的定位策略（本次直接移除无权限 toast）。

## 现状（代码位置）

- Accessibility 权限检查封装：`quicker/Paste/AccessibilityPermission.swift`
  - `SystemAccessibilityPermission.isProcessTrusted(promptIfNeeded:)` 内部调用 `AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": promptIfNeeded])`
- 触发粘贴入口：`quicker/App/AppState.swift`
  - `AppState.pasteClipboardEntry(...)`
  - `AppState.pasteTextBlockEntry(...)`
- 实际发送 `⌘V`：`quicker/Paste/PasteService.swift`（`maybeSendCmdV()` 中会再次检查权限，但 `promptIfNeeded: false`）

## 方案概述（推荐）

在 `AppState.pasteClipboardEntry(...)` 和 `AppState.pasteTextBlockEntry(...)` 的权限检查处，把：

- `permission.isProcessTrusted(promptIfNeeded: false)`

改为：

- `permission.isProcessTrusted(promptIfNeeded: true)`

并移除无权限分支（以及可信分支中的降级结果分支）对 `toast.show(...)` 的调用。

这样当用户首次在无权限状态下尝试粘贴时，会弹出 macOS 系统自带的提示/引导用户去系统设置开启 Accessibility。若用户当下未开启权限，本次操作仍会执行复制（写入剪贴板），但不会再弹出 toast。

## 用户体验与行为细节

- 已授权：
  - 行为保持不变：回到 `previousApp` 并自动发送 `⌘V` 完成粘贴。
- 未授权：
  - 触发一次系统提示（macOS 决定是否显示，通常首次会出现）。
  - 本次不自动粘贴，仅复制到剪贴板。
  - 不展示 toast。

说明：系统提示出现后，用户需要在系统设置中开启权限；开启后回到应用重新触发一次粘贴即可。

## 实现细节（预期改动）

- `quicker/App/AppState.swift`
  - `pasteClipboardEntry(...)`：将 `promptIfNeeded` 设为 `true`；移除 `ToastPresenter` 参数及相关 `toast.show(...)`。
  - `pasteTextBlockEntry(...)`：同上。
  - 保留 `AppState.start()` 里“内存模式降级”的 toast（与权限提示无关）。
- `quickerTests/PastePreviousAppActivationTests.swift`
  - 更新调用签名（不再传 `toast:`）。
  - 断言保持：可信场景下仍会激活 `previousApp`。

## 备选方案（不做）

1) 继续使用 toast，但修复显示策略（例如固定在当前激活屏幕/面板屏幕、延迟关闭面板等）
2) 使用 `NSAlert` 弹窗作为兜底提示
3) 使用 `UNUserNotificationCenter` 发系统通知（需要通知授权）

本次选择推荐方案的原因：改动最小、系统提示足够明显、且不引入新权限。

## 测试计划

- 单元测试：
  - 运行 `quickerTests/PastePreviousAppActivationTests`，确保 trusted 场景仍会激活 `previousApp`。
- 手动验证（本机）：
  1. 在系统设置中关闭/移除 `quicker` 的 Accessibility 权限。
  2. 打开剪贴板面板/文本块面板，选择一条执行粘贴。
  3. 观察是否出现系统提示；确认内容已写入剪贴板且不会出现 toast。
  4. 在系统设置开启 Accessibility 后，再次触发粘贴，确认可自动粘贴回原应用。

## 风险与回滚

- 风险：在某些系统状态下系统提示可能不再弹出（例如用户已取消过、系统策略限制等），且本次移除了 toast，因此用户可能只感知到“没有自动粘贴”。缓解：设置页仍提供“打开系统设置”的入口（`SystemSettingsDeepLink.openAccessibilityPrivacy()`）。
- 回滚：只需将 `promptIfNeeded` 恢复为 `false` 并恢复 toast 提示即可（改动集中在 `AppState` 的两个静态方法）。

