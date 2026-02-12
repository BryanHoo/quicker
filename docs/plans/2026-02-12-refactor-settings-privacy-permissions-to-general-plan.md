# ♻️ 设置面板：将“隐私与权限”从「剪切板」移动到「通用」计划

状态：草案（待确认）

日期：2026-02-12

类型：refactor

## Todo

- [x] 从 `ClipboardSettingsView` 移除 `SettingsSection("隐私与权限")`
- [x] 在 `GeneralSettingsView` 添加 `SettingsSection("隐私与权限")`
- [x] 更新 `SettingsView.Tab.subtitle` 文案（general/clipboard）
- [x] 本地构建通过（`xcodebuild ... build`）
- [x] 勾选本计划中的验收标准

## Overview

把设置面板中目前位于「剪切板」页的 `SettingsSection("隐私与权限")` 移动到「通用」页，减少「剪切板」页的杂项信息，同时让与全局粘贴能力相关的权限入口更符合心智模型（权限影响剪切板/文本块的粘贴行为，而非仅剪切板历史）。

## 背景与动机

当前「剪切板」设置页包含一个「隐私与权限」分区，提供“辅助功能权限”的说明与“打开系统设置”按钮。

但从功能归属看：
- Accessibility（辅助功能）权限用于“粘贴回原应用”，属于全局能力，并非仅剪切板历史。
- 将权限入口放在「通用」页更易被理解与发现（尤其当用户在「通用」页调整快捷键/启动行为时，也可能需要处理权限问题）。

## 目标

- 将现有 `SettingsSection("隐私与权限")` 从 `ClipboardSettingsView` 移动到 `GeneralSettingsView`。
- 更新侧边栏的描述信息（`SettingsView.Tab.subtitle`），确保文案与实际内容一致。
- 不改变权限逻辑与行为，仅调整设置页的信息架构与入口位置。

## 非目标

- 不新增/修改权限检查逻辑（例如 `AXTrustedCheckOptionPrompt` 的触发策略）。
- 不新增新的系统权限种类或系统设置深链。
- 不重做设置面板整体结构（tab 结构保持不变：general/clipboard/textBlock/about）。

## 现状（代码位置）

- 「剪切板」页的权限入口：
  - `quicker/Settings/ClipboardSettingsView.swift:56`（`SettingsSection("隐私与权限")`）
- 侧边栏 tab 副标题：
  - `quicker/Settings/SettingsView.swift:26`（`Tab.subtitle`）
  - 当前 `.clipboard` 返回 `"历史记录、隐私与权限"`（`quicker/Settings/SettingsView.swift:31`）
  - 当前 `.general` 返回 `"快捷键与启动行为"`（`quicker/Settings/SettingsView.swift:29`）
- 打开系统设置（Accessibility）深链：
  - `quicker/System/SystemSettingsDeepLink.swift:4`（`openAccessibilityPrivacy()`）

## 方案（推荐）

### 1) UI 结构调整（最小改动）

1. 在 `quicker/Settings/ClipboardSettingsView.swift` 删除 `SettingsSection("隐私与权限")`。
2. 在 `quicker/Settings/GeneralSettingsView.swift` 增加同等内容的 `SettingsSection("隐私与权限")`（建议放在 `SettingsSection("启动")` 之后）。
3. 在 `quicker/Settings/SettingsView.swift` 更新 `Tab.subtitle`：
   - `.clipboard`：移除“隐私与权限”字样，建议改为更贴近内容的 `"历史记录、忽略应用"`（或你偏好的更短文案）。
   - `.general`：加入“隐私与权限”提示，建议改为 `"快捷键、启动与权限"`（或你偏好的更短文案，注意一行显示长度）。

### 2) 可选：降低“老用户找不到入口”的风险

如果担心已有用户习惯在「剪切板」页找权限入口，可选其一：
- **方案 A（更干净）**：仅通过更新 sidebar subtitle 引导（推荐优先尝试）。
- **方案 B（更明确）**：在 `ClipboardSettingsView` 增加一条轻量提示（非一个完整 section），例如在“历史”或“忽略应用”附近加一行 `Text("权限入口已移动到「通用」")`，并提供一个切换到 `.general` 的按钮/链接（需评估 `SettingsView` 的 tab 状态是否易于从子页驱动）。

> 说明：若采用方案 B，需要额外确认“子页如何驱动切换 tab”的现有架构是否支持；不支持则避免引入额外耦合。

## SpecFlow 分析（要点）

### 用户流概览

1. **首次/临时处理权限**
   - 入口：用户因粘贴失败/提示，打开设置面板 → 进入「通用」→ 点击“打开系统设置”
   - 期望：系统设置打开到 Accessibility 权限页（`SystemSettingsDeepLink.openAccessibilityPrivacy()`）。
2. **老用户按旧路径查找**
   - 入口：打开设置面板 → 进入「剪切板」→ 试图找到“隐私与权限”
   - 期望：不再出现该 section，但能通过 sidebar subtitle（或可选提示）快速定位到「通用」。

### 变体矩阵（关键场景）

| 场景 | 用户入口 | 改动前 | 改动后期望 |
| --- | --- | --- | --- |
| 新用户需要授权 | Settings → general | 需切到 clipboard 才看见入口 | general 直接可见入口 |
| 老用户找入口 | Settings → clipboard | 入口在 clipboard | clipboard 不再有；能被引导到 general |
| 点击按钮 | 任意 | 打开系统设置到 Accessibility | 行为不变 |

### 缺口与风险

- **发现性风险**：老用户可能“凭记忆”到「剪切板」找入口，短期内找不到。
  - 缓解：更新 `Tab.subtitle`（必做）+（可选）轻量提示。
- **文案长度风险**：`Tab.subtitle` 在 sidebar 一行展示，过长会截断。
  - 缓解：选更短、更稳定的关键词组合（如 `"快捷键、启动、权限"` / `"历史、忽略应用"`）。

### 需要确认的问题（不阻塞写代码，但影响最终体验）

1. 是否需要“可选提示（方案 B）”来照顾老用户迁移期体验？还是只改 subtitle 即可？
2. 「通用」页中“隐私与权限”分区的放置位置是否有偏好（启动前/后）？
3. sidebar 的 `Tab.subtitle` 文案希望采用哪组（更短/更具体）？

## 验收标准（Acceptance Criteria）

- [x] 在「剪切板」设置页中，不再显示 `SettingsSection("隐私与权限")`（即不再出现“辅助功能权限 / 打开系统设置”这一块）。
- [x] 在「通用」设置页中，新增 `SettingsSection("隐私与权限")`，内容与旧实现一致：
  - 文案包含“辅助功能权限”
  - 按钮文案为“打开系统设置”
  - 点击后调用 `SystemSettingsDeepLink.openAccessibilityPrivacy()` 并成功打开系统设置对应页面
- [x] `quicker/Settings/SettingsView.swift` 的 sidebar subtitle 与新结构一致（general 包含权限提示；clipboard 不再包含）。
- [x] 不影响其他设置项（快捷键录制、开机自启、历史记录、忽略应用、清空历史等）原有行为（本次仅移动 section + 文案，不触及相关逻辑）。
- [x] （可选）迁移提示：本次不做，先用 sidebar subtitle 引导（如需可再补）。

## 实施步骤（建议任务拆分）

1. **移动 section**
   - 更新 `quicker/Settings/ClipboardSettingsView.swift`：移除 `SettingsSection("隐私与权限")`
   - 更新 `quicker/Settings/GeneralSettingsView.swift`：新增同等 section
2. **更新 sidebar 信息架构文案**
   - 更新 `quicker/Settings/SettingsView.swift`：调整 `.general`/`.clipboard` 的 `subtitle`
3. （可选）**迁移期提示**
   - 仅在决定需要时再做，避免增加 tab 状态耦合

## 测试计划

### 自动化

- 构建：
  ```bash
  xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Debug build
  ```
- 回归测试（如本地环境允许）：
  ```bash
  xcodebuild test -project quicker.xcodeproj -scheme quicker -destination 'platform=macOS'
  ```

### 手动验证（建议）

1. 打开设置面板，进入「剪切板」，确认不再显示“隐私与权限”分区。
2. 进入「通用」，确认显示“隐私与权限 → 辅助功能权限 → 打开系统设置”按钮。
3. 点击“打开系统设置”，确认系统设置跳转到 Accessibility 权限页。
4. 快速扫一眼 sidebar subtitle，确认与实际内容相符且未出现明显截断/歧义。

## 风险与回滚

- 风险：入口迁移导致短期找不到（见上文缓解）。
- 回滚：把 `SettingsSection("隐私与权限")` 放回 `ClipboardSettingsView`，并恢复 `Tab.subtitle` 原文案（改动集中在 2–3 个文件，易回滚）。

## References

### Internal References

- 相关背景（权限入口的重要性）：`docs/plans/2026-02-11-accessibility-permission-reminder-design.md`
- 现有实现位置：
  - `quicker/Settings/ClipboardSettingsView.swift:56`
  - `quicker/Settings/GeneralSettingsView.swift:26`
  - `quicker/Settings/SettingsView.swift:26`
  - `quicker/System/SystemSettingsDeepLink.swift:4`
