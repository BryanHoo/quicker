## Why

当前应用功能基本完成，但每次发布都需要手动在本地构建并打包，流程不稳定且容易出错（环境差异、忘记切换 `Release`、漏传文件等）。我们希望在 push tag（例如 `v1.0.0`）时由 GitHub Actions 自动完成构建与打包，生成可下载的安装包，方便分发给测试/用户，也为后续加入签名与公证打好基础。

## What Changes

- 新增 GitHub Actions workflow：在 push tag（`v*`）时自动构建 `quicker.app` 并打包 `dmg`，发布到 GitHub Releases。
- 在无 Apple Developer 账号/证书的前提下，构建阶段关闭 code signing，确保 CI 可运行。
- 生成并随 release 一起上传 `sha256` 校验文件，便于验证下载文件完整性。
- 提供 `workflow_dispatch` 手动触发入口，用于在未打 tag 时验证构建与打包流程（仅上传 workflow artifact，不发布 release）。

## Capabilities

### New Capabilities
- `github-release-dmg`: push tag 时自动构建 `quicker.app`，生成 `dmg` 并发布到 GitHub Releases（含 `sha256` 校验文件）。

### Modified Capabilities
- 无

## Impact

- 代码/仓库：新增 `.github/workflows/release-dmg.yml` 与 `scripts/ci/package_dmg.sh`（不修改应用运行时代码）。
- 发布体验：产物为**未签名/未公证**的 `dmg`，下载后可能触发 Gatekeeper 提示；后续具备 Developer ID 后可在同一 workflow 增加 `codesign`/`notarytool`/`stapler`。
