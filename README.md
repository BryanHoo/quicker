# quicker

[![Release DMG](https://github.com/BryanHoo/quicker/actions/workflows/release-dmg.yml/badge.svg)](https://github.com/BryanHoo/quicker/actions/workflows/release-dmg.yml)
[![GitHub Release](https://img.shields.io/github/v/release/BryanHoo/quicker)](https://github.com/BryanHoo/quicker/releases)

![App Icon](quicker/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png)

macOS 菜单栏效率工具（Swift 5 / SwiftUI）。包含 `Clipboard/`、`Panel/`、`Paste/`、`Hotkey/`、`Settings/` 等模块。

## 功能

- 剪贴板相关能力（见 `quicker/Clipboard/`）
- 快速面板与粘贴流程（见 `quicker/Panel/`、`quicker/Paste/`）
- 快捷键与设置（见 `quicker/Hotkey/`、`quicker/Settings/`）

> 说明：具体功能以应用内实现与代码为准；如你希望 README 更偏“用户向”或“开发者向”，可以在此基础上再收敛与补充。

## 系统要求

- macOS 14.0+（`MACOSX_DEPLOYMENT_TARGET = 14.0`）
- Xcode（用于本地开发/构建）

## 安装（从 Release 下载）

1. 打开 Releases：<https://github.com/BryanHoo/quicker/releases>
2. 下载对应版本的 `quicker-<version>.dmg`
3. 打开 `dmg`，把 `quicker.app` 拖入 `Applications`

### 关于 Gatekeeper（重要）

当前 Release 产物为**未签名/未公证**的 `dmg`（因为未接入 Developer ID / notarization）。首次运行如果被系统拦截，可尝试：

- 在 Finder 中对 `quicker.app` 右键 → “打开”
- 或在“系统设置”→“隐私与安全性”中允许打开

## 开发

### 打开工程

- Xcode 打开：`quicker.xcodeproj`
- 或命令行构建（Debug / Release）：

```bash
xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Debug build
xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Release build
```

### 测试

```bash
xcodebuild test -project quicker.xcodeproj -scheme quicker -destination 'platform=macOS'
```

> 提示：本应用可能触发系统权限（剪贴板、辅助功能、输入监控等）。本地运行/测试时如遇权限弹窗，请按需授权。

## 发布（GitHub Actions 自动构建 DMG）

本仓库使用 GitHub Actions workflow：`.github/workflows/release-dmg.yml`

- push tag（`v*`）会自动构建并发布到 GitHub Releases
- `workflow_dispatch` 可手动触发用于验证（上传 workflow artifact，不发布 release）

发布一个新版本（示例 `v1.0.1`）：

```bash
git tag -a v1.0.1 -m "v1.0.1"
git push origin v1.0.1
```

产物包含：

- `quicker-v1.0.1.dmg`
- `quicker-v1.0.1.dmg.sha256`

## 贡献

请先阅读仓库贡献指南：`AGENTS.md`

## License

仓库目前未提供 `LICENSE` 文件；如你计划开源/明确授权条款，建议补充对应 license（例如 MIT/Apache-2.0 等）。

