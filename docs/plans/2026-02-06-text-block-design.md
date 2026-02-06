# Quicker 文本块功能设计

日期：2026-02-06  
主题：`text-block-panel`  
范围：新增“文本块（纯文本模板）”能力，支持独立全局快捷键唤出面板并快速插入；新增“设置 - 文本块”Tab 统一管理文本块的增删改与排序。

## 1. 目标与非目标

### 1.1 目标

- 提供独立于剪切板历史的文本块能力，面向高频固定文本快速输入。
- 通过独立全局快捷键唤出单独面板，交互风格与现有剪切板历史面板保持一致。
- 文本块在“设置 - 文本块”Tab 统一管理，覆盖新增、编辑、删除、排序。
- 选择文本块后立即执行插入并关闭面板（行为与用户已确认口径一致）。

### 1.2 非目标（本次不做）

- 富文本/图片文本块。
- 变量占位符（如 `{date}`）与运行时模板渲染。
- 面板内编辑、面板内删除、收藏/分组/搜索。
- 云同步与跨设备共享。

## 2. 已确认交互决策（用户确认）

- 选中条目后：**直接粘贴并关闭面板**。
- 内容类型：**仅纯文本**。
- 快捷键策略：**文本块使用独立全局快捷键**（与剪切板历史互不影响）。
- 排序策略：**固定手动排序**（设置页拖拽排序，面板按固定顺序展示）。
- 编辑边界：**面板只负责选中并插入，所有增删改在设置页完成**。

## 3. 方案对比与选型

### 3.1 备选方案

1) 复用现有剪切板面板与 ViewModel，做双模式分支。  
2) 新建独立 TextBlock 模块，仅复用窗口与粘贴基础设施。  
3) 用 `UserDefaults` 数组做轻量实现。

### 3.2 选型结论

采用方案 2（独立 TextBlock 模块）。

原因：

- 与现有剪切板历史逻辑解耦，避免后续维护中互相污染。
- 回归风险低，便于逐步演进（后续要加分组/搜索时更易扩展）。
- 仍可复用已有能力：`PanelController` 的窗口行为、`PasteService` 的粘贴链路、`HotkeyManager` 的注册机制。

## 4. 架构设计

### 4.1 数据模型与存储

新增 `TextBlockEntry`（SwiftData `@Model`）：

- `uuid: UUID`（建议 `@Attribute(.unique)`，便于去重/导入时 upsert）
- `title: String`
- `content: String`
- `sortOrder: Int`
- `createdAt: Date`
- `updatedAt: Date`

新增 `TextBlockStore`：

- `fetchAllBySortOrder() -> [TextBlockEntry]`
- `create(title:content:)`
- `update(id:title:content:)`
- `delete(id:)`
- `move(fromOffsets:toOffset:)`（重排并重写 `sortOrder`）

存储策略：

- 与现有 `ClipboardEntry` 共用同一个 `ModelContainer`（在 `AppState` 扩展 schema）。
- `title/content` 在写入前做 `trim` 校验，拒绝空内容。

SwiftData 演进策略（新增）：

- 这次引入新模型时，同步规划 `VersionedSchema + SchemaMigrationPlan`，避免后续字段演进时出现不可控迁移风险。
- 若后续需要重命名字段，使用 `@Attribute(originalName:)` 保留历史数据映射，避免“重命名被识别为新增字段”导致的数据丢失。

### 4.2 面板与视图模型

新增：

- `quicker/TextBlock/TextBlockPanelViewModel.swift`
- `quicker/TextBlock/TextBlockPanelView.swift`
- `quicker/TextBlock/TextBlockPanelEntry.swift`（若需要）

职责：

- `TextBlockPanelViewModel` 负责分页、选中项、`⌘1..5` 映射、上下移动。
- `TextBlockPanelView` 负责渲染与键盘事件消费（`Esc`/`Enter`/`↑↓`/`←→`/`⌘1..5`）。

表现要求：

- 布局与视觉风格对齐剪切板面板（统一感知成本）。
- 空状态文案清晰（例如“暂无文本块，请到设置中新增”）。

### 4.3 全局热键与路由

当前 `HotkeyManager` 为单回调模型。为支持“剪切板 + 文本块”双入口，重构为多热键路由：

- 按 `EventHotKeyID` 区分 action（如 `clipboardPanel`、`textBlockPanel`）。
- 独立注册/注销两个热键，互不覆盖。
- 注册失败时返回对应 action 的状态，供设置页展示冲突提示。

新增偏好项（`PreferencesStore`）：

- `textBlockHotkey`
- 可沿用 `Hotkey` 编码格式（`Codable`）

默认值建议：`⌘⇧B`（保留与 `⌘⇧V` 的语义区分，冲突概率较低）。

快捷键约束（新增）：

- 录制与保存阶段增加“保留组合”校验，拒绝系统/辅助功能保留快捷键，并给出明确错误提示。
- 避免覆盖常见应用级惯例快捷键；若用户强制选择高冲突组合，给出风险警告但允许其自行确认。
- 保持“至少包含 `⌘`”规则，降低与输入类按键冲突概率。

### 4.4 应用编排（AppState）

在 `AppState` 中新增：

- `textBlockStore`
- `textBlockPanelViewModel`
- `textBlockPanelController`
- `toggleTextBlockPanel()`
- `refreshTextBlockPanelEntries()`

数据流：

1) 用户按文本块热键  
2) `AppState.refreshTextBlockPanelEntries()` 从 `TextBlockStore` 读取并更新 ViewModel  
3) `PanelController.toggle()` 显示/关闭文本块面板  
4) 用户选择条目  
5) 调用 `PasteService` 写入剪贴板并尝试自动 `⌘V`（无权限则降级复制）  
6) 面板关闭

## 5. 设置页 TextBlock Tab 设计

在 `quicker/Settings/SettingsView.swift` 新增 `.textBlock` Tab，页面为 `TextBlockSettingsView`。

### 5.1 页面结构

- 区域 A：文本块面板快捷键
- 区域 B：文本块列表（支持选择与拖拽排序）
- 区域 C：编辑区（标题 + 内容）
- 区域 D：操作区（新增、删除、上移/下移）

### 5.2 增删改流程（统一在该 Tab）

- 新增：点击“新建文本块”，创建默认项并进入编辑态。
- 编辑：修改标题/内容后自动保存（失焦、切换选中项、关闭设置页时都触发保存），内容为空时禁用保存并提示。
- 删除：二次确认后删除，自动选中相邻项。
- 排序：拖拽后立即持久化 `sortOrder`；同时提供“上移/下移”按钮作为非拖拽替代路径。

### 5.3 快捷键配置

- 复用 `HotkeyRecorderView` 录制。
- 注册失败时提示“快捷键可能冲突，请更换组合”。
- 仅在注册成功后覆盖旧配置，避免把可用热键写坏。

### 5.4 可访问性与键盘优先补充

- TextBlock Tab 内所有核心操作（新增、编辑、删除、重排、保存）都必须可通过键盘完成，不依赖鼠标拖拽。
- 面板与设置页中新增的交互控件必须补齐可访问名称与一致的焦点顺序，确保 VoiceOver 与 Full Keyboard Access 下可用。
- 面板弹出时焦点进入面板；面板关闭后焦点回到合理位置，避免焦点落在不可见背景元素。

## 6. 面板交互规范

- 打开：文本块独立全局热键触发，toggle 行为。
- 关闭：`Esc`、失焦、点击外部。
- 选择：`↑/↓`，翻页 `←/→`，默认选中当前页第 1 项。
- 执行：`Enter` 粘贴选中项并关闭。
- 快捷执行：`⌘1..5` 对应当前页条目，命中后立即粘贴并关闭。
- 禁止项：面板内不提供新增/编辑/删除入口。

## 7. 异常处理与风险控制

- 数据写入失败：显示 toast，保留当前编辑内容，不清空输入。
- 热键注册失败：保留旧热键并提示，不破坏已有可用行为。
- 粘贴降级：无辅助功能权限时仅复制到剪贴板并提示“可手动 `⌘V`”。
- 防误操作：删除动作必须二次确认。

主要风险：

- 双热键重构引入回归（剪切板热键失效或串触发）。
- `sortOrder` 不连续导致排序抖动。

缓解：

- 将热键路由和文本块模块拆分提交，分阶段验证。
- 对重排逻辑补充单测，确保每次 move 后序号连续且稳定。

## 8. 测试与验收

### 8.1 自动化测试

- `TextBlockStoreTests`
  - 新增/编辑/删除/查询
  - 空内容校验
  - `move` 后排序正确且连续
- `TextBlockPanelViewModelTests`
  - 默认选中
  - 上下移动与翻页边界
  - `entryForCmdNumber(1...5)` 映射
- `HotkeyManager` 相关测试（可用逻辑层抽象）
  - 双 action 注册与路由分发
  - 保留快捷键校验与冲突分级提示

### 8.2 手测清单

- 文本块热键可稳定唤出，且不影响剪切板热键。
- 设置页新增/编辑/删除/排序后，面板立即反映最新内容与顺序。
- `Enter` 与 `⌘1..5` 均能“插入并关闭”。
- 重启应用后文本块内容、顺序、热键配置保持。
- 在 Full Keyboard Access 开启时，Tab 内所有操作可只用键盘完成（含重排替代路径）。

## 9. 实施顺序（建议）

1) 数据层：`TextBlockEntry` + `TextBlockStore` + 基础单测。  
2) 设置层：`TextBlockSettingsView` + Tab 接入 + 增删改排序。  
3) 热键层：`HotkeyManager` 多路由重构 + `textBlockHotkey` 偏好。  
4) 面板层：`TextBlockPanelViewModel` + `TextBlockPanelView` + `AppState` 编排。  
5) 回归与验收：覆盖双热键与粘贴降级场景。

## 10. 外部最佳实践依据（2026-02-06 检索）

- SwiftData schema 演进建议（`@Attribute(.unique)`、`@Attribute(originalName:)`、`VersionedSchema`、`SchemaMigrationPlan`）：  
  `https://developer.apple.com/videos/play/wwdc2023/10195/`
- 可访问性与键盘导航（支持 Full Keyboard Access、避免覆盖系统快捷键）：  
  `https://developer.apple.com/design/human-interface-guidelines/accessibility`
- 文件/编辑类交互中的保存策略（避免要求用户频繁显式保存，推荐自动保存）：  
  `https://developer.apple.com/design/human-interface-guidelines/file-management`
- 保留/常用快捷键不要重载（系统保留组合与应用惯例组合）：  
  `https://developer.apple.com/library/archive/documentation/UserExperience/Conceptual/AppleHIGuidelines/XHIGKeyboardShortcuts/XHIGKeyboardShortcuts.html`
- VoiceOver 可用性验收口径（常见任务应可仅通过辅助技术完成）：  
  `https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria/`
