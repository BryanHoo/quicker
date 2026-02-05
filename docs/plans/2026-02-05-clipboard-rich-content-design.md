# Quicker 富文本/图片复制粘贴设计

日期：2026-02-05  
主题：`clipboard-rich-content`  
范围：在现有“文本剪贴板历史 + 面板粘贴”基础上，新增对 **富文本（RTF）** 与 **图片** 的采集、持久化、预览与粘贴。

## 1. 目标与非目标

### 1.1 目标

- 复制 **RTF** 或 **图片** 时也能进入历史列表，并可从面板选择后粘贴回前台 App。
- 粘贴策略保持现有一致性：写入剪贴板 +（若已授权辅助功能）模拟 `⌘V`；未授权则仅写入剪贴板并提示。
- 图片持久化：SwiftData 仅保存图片路径；真实图片写入磁盘，并随“清空/裁剪”同步删除。
- 兼容性：每次写回剪贴板尽量携带可降级的纯文本（RTF 同时写 `.string`）。

### 1.2 非目标（本次不做）

- Snippets、Pin/收藏、按类型筛选、文件（file URL）类型、云同步。
- 备份并恢复所有 `NSPasteboardItem` 的全部 type（避免数据量/隐私/兼容性问题）。

## 2. 关键决策

- 富文本仅支持 `NSPasteboard.PasteboardType.rtf`（RTF）。  
  - 预览/降级：从 RTF 中提取纯文本作为列表显示与 `.string` 降级写回。
- 图片优先识别 `NSPasteboard.PasteboardType.png`，其次 `NSPasteboard.PasteboardType.tiff`（转 PNG 落盘）。
- 去重策略从“相邻文本相等”升级为“相邻 `kind + contentHash` 相等”。
- 图片文件命名：基于内容的 `SHA256`（`<hash>.png`），支持复用与去重。

## 3. 数据模型（SwiftData）

现有 `ClipboardEntry`（`quicker/Clipboard/ClipboardEntry.swift`）扩展为可承载多类型内容，字段均尽量可选以便轻量迁移：

- `text: String`（保留）
  - `.text`：真实文本（trim 后）
  - `.rtf`：从 RTF 提取的纯文本（trim 后）
  - `.image`：固定预览文本（例如 `"图片"`）
- `createdAt: Date`（保留）
- `kindRaw: String?`：`"text" | "rtf" | "image"`；旧数据为 `nil` 时按 `"text"` 处理
- `rtfData: Data?`：仅 `.rtf` 使用，存 `NSPasteboard.PasteboardType.rtf` 的原始 Data
- `imagePath: String?`：仅 `.image` 使用，存相对路径/文件名（指向 Application Support 目录下的 png）
- `contentHash: String?`：用于相邻去重与图片文件命名（`SHA256` 的十六进制字符串）

## 4. 磁盘资产（图片）

新增 `ClipboardAssetStore`（建议放在 `quicker/Clipboard/ClipboardAssetStore.swift`）：

- 根目录：`Application Support/<bundleIdentifier>/clipboard-assets/`
- API（建议）：
  - `saveImage(pngData: Data, contentHash: String) throws -> String`：写入 `<contentHash>.png`，返回相对路径
  - `loadImageData(relativePath: String) throws -> Data`
  - `deleteImage(relativePath: String) throws`
- 清理策略：
  - `ClipboardStore.clear()` 删除条目时同步删除 `imagePath`
  - `ClipboardStore.trimToMaxCount()` 删除被裁剪的条目时同步删除 `imagePath`
  - 若文件名复用（同 hash），删除前需确认没有其他条目仍引用该 `imagePath`

## 5. 剪贴板采集（监听 NSPasteboard）

将 `PasteboardClient`（`quicker/Clipboard/PasteboardClient.swift`）从 `readString()` 升级为读取结构化内容：

### 5.1 采集优先级

1) 图片：存在 `.png` 或 `.tiff` 即视为图片  
2) 富文本：存在 `.rtf` 即视为富文本  
3) 纯文本：读取 `.string`

### 5.2 RTF → 预览文本

- `rtfData` 直接持久化
- 用 `NSAttributedString(rtf:documentAttributes:)` 提取 `string` 作为 `text` 预览与 `.string` 降级

### 5.3 TIFF → PNG

- 若只有 `.tiff`：用 `NSImage(data:)` + `NSBitmapImageRep` 转为 `pngData` 再落盘

### 5.4 去重（相邻）

- `contentHash`：
  - `.text`：对 `trimmed.utf8` 做 `SHA256`
  - `.rtf`：对 `rtfData` 做 `SHA256`
  - `.image`：对 `pngData` 做 `SHA256`
- 相邻去重判断改为：若 `latest.kindRaw` 与 `contentHash` 相同则跳过

## 6. 面板展示（预览）

面板当前仅支持 `String`，需要升级为展示条目对象：

- `ClipboardPanelViewModel.entries` 从 `[String]` 改为 `[ClipboardPanelItem]`（或直接 `[ClipboardEntry]`）
- `ClipboardPanelView.onPaste` 入参从 `String` 改为条目对象
- 行渲染：
  - `.text/.rtf`：显示 `text`（纯文本预览）
  - `.image`：显示缩略图 + `"图片"`
- 缩略图：使用 `CGImageSourceCreateThumbnailAtIndex` 从 png 文件生成小图（避免解码全尺寸）

## 7. 粘贴写回（NSPasteboard 写入）

扩展 `PasteService`（`quicker/Paste/PasteService.swift`）与 `PasteboardWriting`（`quicker/Paste/SystemPasteboardWriter.swift`）：

- `.text`：写 `.string`
- `.rtf`：写 `.rtf`，并同时写 `.string`（降级）
- `.image`：读取 `imagePath` 对应 png，写 `.png`；可选补写 `.tiff`（提升兼容性）

保持现有权限逻辑：

- 已授权辅助功能：写入剪贴板后模拟 `⌘V`
- 未授权：仅写入剪贴板并提示（toast）

## 8. 错误处理与降级

- 采集：
  - RTF 解析失败：回退 `.string`
  - 图片转换/写盘失败：不插入历史（避免坏条目）
- 粘贴：
  - 图片文件缺失：toast 提示“图片已丢失”，并可删除该条目（避免反复失败）
  - RTF 缺失：回退 `.string`

## 9. 测试策略

新增/调整单测（优先覆盖纯逻辑）：

- `ClipboardStore`：
  - 相邻去重升级为 `kind + contentHash`
  - 删除/裁剪时触发图片文件清理（可通过 fake asset store 验证）
- 采集逻辑：
  - 优先级：image > rtf > string
  - tiff → png 转换分支
- `PasteService`：
  - trusted / untrusted 下的行为一致性
  - `.rtf` 同时写 `.rtf` 与 `.string`
  - `.image` 写 `.png`（以及可选 `.tiff`）

## 10. 实施顺序（建议）

1) 扩展 `ClipboardEntry` + 轻量迁移验证  
2) 引入 `ClipboardAssetStore` + `contentHash`（`CryptoKit`）  
3) 升级 `PasteboardClient` / `ClipboardMonitorLogic` / `ClipboardStore.insert(...)`  
4) 升级面板 ViewModel + UI（图片缩略图）  
5) 升级 `PasteService`/writer 支持 `.rtf/.image`  
6) 补齐测试与手测验收清单

