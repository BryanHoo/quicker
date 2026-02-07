## Context

`quicker` 是 macOS 菜单栏应用（`quicker.xcodeproj`）。目前发布流程需要在本地构建并手动打包，重复劳动且不可复现。目标是在不依赖 Apple Developer 账号的前提下，通过 GitHub Actions 自动构建并产出可分发的 `dmg` 安装包。

约束：
- 现阶段无 Developer ID 证书，无法做 `codesign` 与 notarization，因此产物会是未签名/未公证的 `dmg`。
- Workflow 需要尽量简单、可本地复现；并为未来加入签名/公证预留扩展点。

## Goals / Non-Goals

**Goals:**
- push tag（`v*`）自动构建 `Release` 并生成 `dmg` + `sha256`，发布到 GitHub Releases。
- 允许 `workflow_dispatch` 手动触发用于验证（上传 artifact，不发布 release）。
- 构建过程中显式关闭 code signing，确保在无证书环境下可运行。

**Non-Goals:**
- 不实现 Developer ID 签名、公证（notarization）与 stapling。
- 不做精美的 DMG 布局（背景图、窗口位置、拖拽提示等）。
- 不改变应用运行时代码与功能行为。

## Decisions

### Decision: 使用 GitHub Actions + `softprops/action-gh-release` 发布 Release
**Choice**: 在 workflow 中使用 `softprops/action-gh-release@v2` 创建/更新 GitHub Release 并上传附件。
**Why**: 配置简单、仅依赖 `GITHUB_TOKEN`，不需要额外安装 `gh` 或维护复杂 API 调用。
**Alternatives**:
- 使用 `gh release create`: 需要 runner 预装/安装 `gh`，脚本与权限处理更复杂。
- 使用 `actions/create-release`/`actions/upload-release-asset`: 维护状态不如 `softprops/action-gh-release` 活跃，且需要拆成多个步骤。

### Decision: 使用 `xcodebuild build` 并通过环境变量关闭 code signing
**Choice**: 采用 `xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Release build`，并设置 `CODE_SIGNING_ALLOWED=NO` 等参数关闭签名。
**Why**: 当前只需要产出可运行的 `quicker.app` 用于打包，不需要 `archive`/`export` 流程；关闭签名能在无证书环境直接构建成功。
**Alternatives**:
- `xcodebuild archive` + `xcodebuild -exportArchive`: 更偏向签名/分发场景，未签名时收益不大，配置更繁琐。

### Decision: 将 DMG 打包逻辑抽到 `scripts/ci/package_dmg.sh`
**Choice**: workflow 调用仓库内脚本完成复制 `.app`、创建 `Applications` 软链接、`hdiutil create` 生成 `dmg`，并输出到 `build/artifacts/`。
**Why**: 降低 YAML 复杂度，便于本地复现与后续扩展（例如加入签名/公证前置步骤）。
**Alternatives**:
- 全部写在 workflow YAML 中：可读性差，维护成本高，本地复现不方便。

## Risks / Trade-offs

- [Risk] 未签名/未公证 `dmg` 会触发 Gatekeeper 提示 → Mitigation: 在 release 说明中提示“右键打开/系统设置放行”，并在未来可无缝增加签名/公证步骤。
- [Risk] Runner 上 Xcode 版本变动导致构建失败 → Mitigation: 保持 workflow 简单；必要时引入 `setup-xcode` 固定版本。

## Migration Plan

无需迁移。合入后即可通过创建 tag（例如 `git tag v1.0.0 && git push origin v1.0.0`）触发发布。

## Open Questions

- 是否需要同时上传 `quicker.app.zip` 作为备用分发形式（目前先不做，保持最小化）。

