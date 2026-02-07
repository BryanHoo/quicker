# quicker

[![Release DMG](https://github.com/BryanHoo/quicker/actions/workflows/release-dmg.yml/badge.svg)](https://github.com/BryanHoo/quicker/actions/workflows/release-dmg.yml)
[![GitHub Release](https://img.shields.io/github/v/release/BryanHoo/quicker)](https://github.com/BryanHoo/quicker/releases)

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

### 安装权限

```bash
sudo xattr -dr com.apple.quarantine /Applications/quicker.app
```

## 反馈与建议

- Bug / 功能建议：<https://github.com/BryanHoo/quicker/issues>
