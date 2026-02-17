# 剪贴板历史面板与文本块面板搜索功能设计文档

状态：定稿（已确认）

日期：2026-02-17

## 背景

当前 `ClipboardPanelView`（剪贴板历史面板）与 `TextBlockPanelView`（文本块面板）均为分页列表展示，支持 `Esc/Enter/↑↓/←→/⌘数字/⌘,` 等快捷键操作。随着历史记录与文本块数量增加，用户需要在面板内快速定位目标条目，因此需要引入搜索能力，同时保持现有快捷键体验不被破坏，并兼容中文输入法。

## 目标

- 在剪贴板历史面板与文本块面板的 header 中新增搜索框，支持实时过滤。
- 搜索框聚焦时仍可使用现有快捷键（尤其是 `↑↓/←→/Enter/⌘数字/⌘,`）。
- 每次打开面板时清空搜索（展示完整列表）并自动聚焦搜索框。
- 文本块搜索同时匹配 `title` 与 `content`。

## 非目标

- 不做跨次打开面板保留搜索词。
- 不做复杂的模糊搜索、权重排序、匹配高亮。
- 不新增/变更持久化结构（不引入新的 SwiftData 字段或索引）。

## 现状（代码位置）

- 剪贴板历史面板：
  - UI：`quicker/Panel/ClipboardPanelView.swift`
  - ViewModel：`quicker/Panel/ClipboardPanelViewModel.swift`
  - 条目：`quicker/Panel/ClipboardPanelEntry.swift`（关键字段：`previewText`）
- 文本块面板：
  - UI：`quicker/TextBlock/TextBlockPanelView.swift`
  - ViewModel：`quicker/TextBlock/TextBlockPanelViewModel.swift`
  - 条目：`quicker/TextBlock/TextBlockPanelEntry.swift`（关键字段：`title`、`content`）
- 键盘命令：
  - 解析：`quicker/Panel/PanelKeyCommand.swift`
  - 事件捕获：`quicker/Panel/KeyEventHandlingView.swift`（当前通过 `NSViewRepresentable` 的 firstResponder 捕获）

## 方案概述（已选定）

采用 **方案 1：纯 SwiftUI `TextField` 作为搜索框**，并新增 **本地键盘事件 monitor** 以确保搜索框聚焦时仍能触发面板快捷键。

该方案的关键点：

- 搜索框实现简洁，不引入额外 AppKit 桥接（相比 `NSSearchField` 更少胶水代码）。
- 通过 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` 统一处理面板快捷键，避免焦点在 `TextField` 时快捷键失效。
- 为避免破坏文本编辑体验：只拦截“无修饰键”的方向键（`↑↓←→`），带 `⌘/⌥/⇧` 的方向键交由 `TextField` 自行处理。

## UI 设计

### Header 布局

两面板 header 改为两行：

1. 第一行：保留现有 icon + 标题 + `⌘,` 设置提示。
2. 第二行：新增搜索框（放大镜 icon + `TextField` + 清除按钮）。

搜索框：

- placeholder：`搜索`
- 清除按钮：仅在 query 非空时显示，点击后清空 query 并保持焦点。
- `onAppear`：自动聚焦。

### 空状态

- 原始数据为空：保持现有“暂无历史记录/暂无文本块…”。
- 原始数据非空但过滤后为空：显示“无匹配结果”。
  - macOS 14+：使用 `ContentUnavailableView`
  - 低版本：用 `Text` 兜底

## 匹配规则

### 剪贴板历史面板

- 搜索字段：`ClipboardPanelEntry.previewText`
  - 文本/RTF：预览文本
  - 图片：预览文件名
- 匹配方式：本地化包含匹配（不区分大小写），例如 `localizedStandardContains`

### 文本块面板

- 搜索字段：`TextBlockPanelEntry.title` + `TextBlockPanelEntry.content`
- 匹配方式：本地化包含匹配（不区分大小写）
- 命中规则：任一字段命中即显示该条目

## 数据流与 ViewModel 设计

为避免搜索影响数据源刷新与分页逻辑，在两个 ViewModel 内引入“原始结果集 + 过滤结果集”的结构。

### 新增字段

在 `ClipboardPanelViewModel` / `TextBlockPanelViewModel` 增加：

- `@Published var searchQuery: String = ""`
- `private var allEntries: [Entry] = []`（保存未过滤的原始数据）
- `var filteredEntries: [Entry]`（根据 `allEntries` + `searchQuery` 计算）

### 关键行为

- `setEntries(_:)`：
  - 更新 `allEntries`
  - **清空 `searchQuery`**（每次打开面板都回到完整列表）
  - 重置 `pageIndex = 0`、`selectedIndexInPage = 0`
- 当 `searchQuery` 变化时：
  - 过滤结果变化时，重置 `pageIndex = 0`、`selectedIndexInPage = 0`，避免过滤后选中越界
- 分页与选择：
  - `pageCount` / `visibleRange` / `visibleEntries` / `selectedEntry` / `entryForCmdNumber(_:)` 全部基于 `filteredEntries`
  - 因此 `⌘数字` 始终对应“当前过滤结果的当前页”

## 键盘事件与焦点策略

### 搜索框焦点

- 使用 `@FocusState` 管理搜索框焦点。
- 面板展示时自动聚焦搜索框（用户确认）。

### 本地键盘 monitor

新增一个 SwiftUI 组件（暂名 `PanelKeyCommandMonitor`）：

- 在 `onAppear`：
  - 注册 `NSEvent.addLocalMonitorForEvents(matching: .keyDown)`
- 在 `onDisappear`：
  - 移除 monitor，避免泄漏与影响其他窗口

monitor 拦截规则：

- 拦截：`Esc/Enter/↑↓/←→/⌘数字/⌘,`
- 方向键：仅当事件 **没有** `⌘/⌥/⇧` 修饰时才拦截（带修饰时交给 `TextField`，保留光标移动/选词等能力）
- 其他字符输入、输入法组合输入：不拦截（确保中文输入法正常工作）

### `Esc` 行为

- 用户选择：`Esc` **始终关闭面板**（不做“先清空搜索”）

### 现有 `KeyEventHandlingView`

- 保留现有 `KeyEventHandlingView` + `handleKeyDown(_:)` 逻辑作为兜底（在 monitor 失效或非预期情况下仍可工作）。

## 测试计划

单元测试为主，确保过滤与分页/快捷键映射逻辑正确：

- `quickerTests/ClipboardPanelViewModelTests.swift`
  - 增加：过滤后 `pageIndex`/`selectedIndexInPage` 重置
  - 增加：`entryForCmdNumber(_:)` 基于过滤结果
- `quickerTests/TextBlockPanelViewModelTests.swift`
  - 增加：`title` 或 `content` 命中都能显示
  - 增加：过滤后分页与选择行为正确

手动验证（本机）：

1. 打开剪贴板面板，直接输入查询，观察列表实时过滤；`Esc` 关闭；再次打开列表恢复完整并聚焦搜索框。
2. 搜索框聚焦时按 `↑↓/←→/Enter/⌘数字/⌘,`，确认均生效。
3. 打开文本块面板，分别用 title 与 content 关键词验证匹配。
4. 使用中文输入法输入（组合输入/候选），确认不会被快捷键 monitor 破坏。

## 风险与回滚

风险：

- 本地 monitor 若未及时移除，可能影响应用其他窗口的按键处理；需要严格绑定面板生命周期。
- 方向键在搜索框聚焦时将优先用于列表导航（无修饰键），可能与部分用户“在输入框内移动光标”的习惯冲突；通过保留带修饰键方向键的文本编辑能力降低影响。

回滚：

- 移除 header 搜索框与相关 ViewModel 字段/过滤逻辑，并删除键盘 monitor 组件即可，改动集中在两个面板与两个 ViewModel 中。

