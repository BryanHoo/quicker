# 剪贴板面板条目布局重设计（避免遮挡 + 时间/图片名）

## 背景

当前剪贴板面板（`quicker/Panel/ClipboardPanelView.swift`）外层容器使用固定尺寸（`QuickerTheme.ClipboardPanel.size`）。列表行在 `entry.kind == .image` 时会插入 `32x32` 的缩略图，但文本/RTF 行没有对应的 leading 区域，导致图片行高度更大、整体列表在固定高度下出现底部条目被裁切/遮挡的观感问题。同时图片条目预览文本在 `AppState.makePanelEntries` 中写死为“图片”，信息量不足。

## 目标

- 图片条目与文本条目视觉高度一致、对齐一致
- 固定面板高度下不再出现底部条目被遮挡
- 行内新增“复制时间”显示（格式：`MM-dd HH:mm`）
- 图片条目显示具体图片名（从 `imagePath` 提取文件名），不再只显示“图片”
- 整体保持现有面板风格（材质背景、选中态、字体体系）

## 方案

### 面板尺寸

- 将 `QuickerTheme.ClipboardPanel.size.height` 从 `276` 调整为约 `332`，确保每页 5 条在两行信息布局下仍可完整显示。

### 行布局（统一高度）

- `ClipboardEntryRow` 使用统一的 leading 区域（固定 `32x32`）：
  - `.image`：显示缩略图
  - `.text/.rtf`：显示对应 icon（占位样式与缩略图一致）
- 主信息区改为两行：
  - 第 1 行：`previewText`（单行省略）
  - 第 2 行：`createdAt` 格式化为 `MM-dd HH:mm`（secondary 样式、`monospacedDigit()`）
- 右侧保留 `⌘1..⌘5` 快捷键提示，与主信息第 1 行同一行对齐。
- 通过固定 leading 尺寸 + 合理 padding，保证所有条目行高一致，从根源上消除“图片行更高”带来的裁切风险。

### 数据结构与映射

- 扩展 `ClipboardPanelEntry`：新增 `createdAt: Date`
- `AppState.makePanelEntries(from:)`：
  - 直接映射 `ClipboardEntry.createdAt`
  - `.image` 的 `previewText` 改为 `imagePath` 的文件名（`lastPathComponent`），并为缺失路径提供兜底文本

## 验证

- 运行现有单元测试（特别是 `quickerTests/ClipboardPanelViewModelTests.swift` / `quickerTests/ClipboardPanelViewModelRichTests.swift`）确保编译与逻辑正确
- 手动验证：打开面板确认每页 5 条不再遮挡、图片条目显示文件名且有时间信息

