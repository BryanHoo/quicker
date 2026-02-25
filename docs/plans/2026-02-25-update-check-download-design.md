# 设计：启动后检查更新并下载 GitHub Release DMG

日期：2026-02-25

## 背景

当前更新方式是用户自行前往 GitHub Releases 查看并下载最新版本。用户在有新版本时不会收到提示，也不知道需要更新。

同时，仓库的发布工作流支持“可能不签名”的构建模式；在这种情况下，不适合在 App 内实现“自动替换安装”（安全与权限持久化风险更高）。

## 目标（Goals）

- 每次启动后延迟一段时间自动检查是否有新版本。
- 若有新版本，弹出对话框提示用户，并提供“一键下载最新 DMG”能力。
- 下载完成后自动打开 `.dmg`，引导用户手动拖拽覆盖安装。

## 非目标（Non-goals）

- 不做“自动替换/静默安装/后台升级”。
- 不引入 Sparkle/appcast 更新链路。
- 不做复杂的下载进度 UI（首版仅提示开始/完成/失败）。

## 用户体验（UX）

### 触发时机

- App 每次启动后延迟约 10 秒触发一次更新检查。
- 单次启动周期内最多弹一次更新提示（避免重复打扰）。

### 弹窗文案与按钮（NSAlert）

- 标题：发现新版本 `vX.Y.Z`
- 内容：当前版本 `A.B.C`，是否下载更新？下载完成后会自动打开 DMG，需要手动拖拽覆盖安装。
- 按钮：
  - `下载并打开 DMG`（默认）
  - `稍后`
  - `查看 Release`（打开浏览器到 GitHub Release 页面）

### 下载与反馈

- 选择下载后，使用 `ToastPresenter` 提示：
  - 开始：`开始下载更新…`
  - 成功：`下载完成，正在打开…`
  - 失败：`下载失败：<原因>`（同时提供“查看 Release”作为降级路径）

## 更新源与版本判断

### 更新源（GitHub Releases API）

- 请求：`GET https://api.github.com/repos/BryanHoo/quicker/releases/latest`
  - 预期返回“最新非 prerelease 的 release”
- 必要字段：
  - `tag_name`：如 `v1.0.10`
  - `html_url`：用于“查看 Release”
  - `assets[]`：用于选择并下载 `*.dmg` 及可选的 `*.sha256`

请求头建议：
- `Accept: application/vnd.github+json`
- `User-Agent: quicker`

### 当前版本

- 从 `CFBundleShortVersionString` 读取当前版本号，例如 `1.0.9`。

### 版本对比策略

- 远端版本取 `tag_name` 并去掉前缀 `v`（若存在）。
- 按语义版本（`major.minor.patch`）比较：
  - 仅当远端版本 `>` 当前版本时提示更新。
- 解析失败或格式异常时：
  - 不弹窗，记录日志并降级为仅提供“查看 Release”（可在后续加入手动入口时使用）。

## 资产选择与下载策略

### 资产选择

在 `assets` 中：
- 选择 `name` 以 `.dmg` 结尾的资产。
- 若存在多个 `.dmg`：
  - 优先 `name` 以 `quicker-` 开头的资产；
  - 仍冲突则按 `size` 最大者优先（通常只有一个）。
- 可选：若存在同名 `.dmg.sha256`，一并下载用于完整性校验。

### 保存位置

- 保存到 `Application Support/quicker/Updates/`（避免需要访问 Downloads 权限）。
- 文件名使用 asset 原始 `name`，例如 `quicker-v1.0.10.dmg`。

### 复用与重复下载

- 若目标文件已存在：
  - 若存在 `.sha256` 校验信息并校验通过：直接打开 `.dmg`；
  - 否则删除旧文件并重新下载（避免用户误用损坏文件）。

### 完整性校验（可选但推荐）

若存在 `*.dmg.sha256`：
- 解析文件首个 token 作为期望 hash（兼容 `shasum -a 256` 的输出格式：`<hash>  <filename>`）。
- 下载 `.dmg` 后计算 SHA-256（可复用现有 `ContentHash.sha256Hex(_:)`）。
- 若校验失败：
  - toast 提示校验失败；
  - 删除下载的 `.dmg`；
  - 降级为打开 `html_url` 让用户手动处理。

## 系统行为：打开 DMG

- 下载成功且（如有）校验通过后，使用 `NSWorkspace.shared.open(fileURL)` 打开 `.dmg`。

## 错误处理与降级

- 网络不可用 / GitHub API 失败 / 403 rate limit：
  - 不弹更新对话框或在对话框中提示失败原因；
  - 降级为“查看 Release”（打开 `html_url`）。
- 下载中途失败：
  - toast 提示失败原因；
  - 保持可重试（下次启动或后续增加手动入口）。

## 代码结构（拟新增模块）

新增目录：`quicker/Update/`

- `AppUpdateManager`（`@MainActor`）
  - 启动延迟检查
  - 版本对比
  - `NSAlert` 交互
  - 触发下载与打开
- `GitHubReleaseClient`
  - 请求 `/releases/latest` 并解析必要字段
- `SemanticVersion`
  - 解析/比较 `CFBundleShortVersionString` 与 `tag_name`
- `UpdateDownloader`
  - 选择资产
  - 下载到 Application Support
  - 可选 sha256 校验

集成点：
- 在 `AppState.start()` 中启动 `AppUpdateManager` 的“启动后延迟检查”流程。

## 测试策略（最小覆盖）

- 单元测试（`quickerTests`）：
  - `SemanticVersion`：解析与比较（含 `v` 前缀、缺字段、非数字）
  - `.sha256` 解析：提取 hash token
  - 资产选择：多个 `.dmg` 的优先级规则
- 网络层测试：
  - 使用 `URLProtocol` stub `URLSession`，覆盖成功/失败/限流响应解析（首版可先不做，按复杂度取舍）。

## 未来增强（不在本次范围）

- 在菜单栏或 About 页面增加“检查更新…”与“更新日志…”入口。
- 增加下载进度 UI 与取消能力。
- 支持 prerelease/频道选择（如 Beta）。

