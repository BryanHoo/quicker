# quicker

[![Release DMG](https://github.com/BryanHoo/quicker/actions/workflows/release-dmg.yml/badge.svg)](https://github.com/BryanHoo/quicker/actions/workflows/release-dmg.yml)
[![GitHub Release](https://img.shields.io/github/v/release/BryanHoo/quicker)](https://github.com/BryanHoo/quicker/releases)

![App Icon](quicker/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png)

macOS 菜单栏效率工具：提供剪贴板历史与“文本块”（常用模板文本）快速插入。

## 功能亮点

- 剪贴板历史：复制文本 / 富文本 / 图片后可在面板中快速选择并粘贴
- 文本块：把常用模板文本收纳起来，一键插入到当前应用
- 快捷键唤起：默认 `⌘⇧V`（剪贴板面板）、`⌘⇧B`（文本块面板），可在设置中修改
- 隐私控制：支持“忽略应用”、一键清空历史、限制最大历史条数

## 系统要求

- macOS 14.0+

## 安装（从 Release 下载）

1. 打开 Releases：<https://github.com/BryanHoo/quicker/releases>
2. 下载对应版本的 `quicker-<version>.dmg`
3. 打开 `dmg`，把 `quicker.app` 拖入 `Applications`

可选：校验下载文件完整性（下载目录中同时有 `dmg` 与 `sha256` 文件时）：

```bash
shasum -a 256 -c quicker-<version>.dmg.sha256
```

### 关于 Gatekeeper（重要）

当前 Release 产物为**未签名/未公证**的 `dmg`（因为未接入 Developer ID / notarization）。首次运行如果被系统拦截，可尝试：

- 在 Finder 中对 `quicker.app` 右键 → “打开”
- 或在“系统设置”→“隐私与安全性”中允许打开

## 快速开始

### 1) 打开面板

- 打开剪贴板面板：默认 `⌘⇧V`（设置中显示为 `⌘⇧V` / “剪切板面板”）
- 打开文本块面板：默认 `⌘⇧B`

也可以点击菜单栏图标，使用菜单项：
`Open Clipboard Panel` / `Open Text Block Panel` / `Settings…` / `Clear History`

### 2) 在面板里选择并粘贴/插入

- 选择：`↑` / `↓`
- 翻页：`←` / `→`
- 执行：`Enter`
- 关闭：`Esc`
- 快速选择：`⌘1` ~ `⌘5`
- 打开设置：`⌘,`

### 3) 辅助功能权限（建议开启）

如果你希望 Quicker 在选中条目后**自动回到原应用并粘贴**，需要开启“辅助功能权限”。  
你可以在设置面板的“剪切板”页点击“打开系统设置”一键跳转。

未开启权限时，Quicker 仍会把内容复制到剪贴板，并提示你手动 `⌘V`。

## 设置说明

打开设置：菜单栏 → `Settings…`（或在任一面板按 `⌘,`）

### 通用

- 快捷键：修改“剪切板面板 / 文本块面板”唤起快捷键（建议包含 `⌘`，且两者不能相同）
- 启动：开机自启

### 剪切板

- 最大条数：默认 200；设为 0 会自动清空并停止保留历史
- 相邻去重：默认开启（连续复制相同内容时只保留一条）
- 忽略应用：来自这些应用的复制内容不会被记录
- 历史记录：可一键清空（不可撤销）

### 文本块

- 新增/编辑/删除常用模板文本，并支持排序（常用的放前面，方便 `⌘1` 快速插入）
- 在“文本块列表”里可用 `⌘N` 快速新增

## 常见问题

### 快捷键无效或冲突？

到设置面板 → “通用”里换一个组合键；如果提示冲突，说明可能与系统或其他应用快捷键重叠。

### 不能自动粘贴到原应用？

请在设置面板 → “剪切板”里开启“辅助功能权限”。未开启时可手动 `⌘V`。

### 不想记录某些应用的复制内容？

到设置面板 → “剪切板” → “忽略应用”添加对应应用。

## 卸载

1. 退出 Quicker
2. 删除 `Applications/quicker.app`
3. 可选：删除本地数据（会清空历史与设置）
   - `~/Library/Application Support/space.bryanhu.quicker`
   - `~/Library/Containers/space.bryanhu.quicker`

## 反馈与建议

- Bug / 功能建议：<https://github.com/BryanHoo/quicker/issues>

## 开发者

如果你需要从源码构建或参与贡献，请先阅读：`AGENTS.md`

### 维护者：发布（GitHub Actions 自动构建 DMG）

本仓库使用 GitHub Actions workflow：`.github/workflows/release-dmg.yml`

- push tag（`v*`）会自动构建并发布到 GitHub Releases
- `workflow_dispatch` 可手动触发用于验证（上传 workflow artifact，不发布 release）

发布一个新版本（示例 `v1.0.1`）：

```bash
git tag -a v1.0.1 -m "v1.0.1"
git push origin v1.0.1
```

## License

仓库目前未提供 `LICENSE` 文件；如你计划开源/明确授权条款，建议补充对应 license（例如 MIT/Apache-2.0 等）。
