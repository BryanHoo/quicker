## ADDED Requirements

### Requirement: Tag 触发 Release DMG 构建与发布
当仓库收到符合 `v*` 的 git tag push 时，GitHub Actions MUST 运行 `Release DMG` workflow，并完成以下产物与发布：
- 构建 `quicker.xcodeproj` 的 scheme `quicker`（`Release` 配置）
- 关闭 code signing（不依赖 Apple Developer 账号/证书）
- 生成 `dmg` 安装包与 `sha256` 校验文件
- 将产物作为附件发布到与该 tag 同名的 GitHub Release

#### Scenario: Push tag `v1.0.0` 后生成并发布 release 附件
- **WHEN** push tag `v1.0.0`
- **THEN** GitHub Release 附件中包含 `quicker-v1.0.0.dmg` 与 `quicker-v1.0.0.dmg.sha256`

### Requirement: workflow_dispatch 支持手动验证（不发布 release）
当使用 `workflow_dispatch` 手动触发 workflow 时，流程 MUST 完成构建与打包，但 MUST NOT 创建/更新 GitHub Release；产物 MUST 以 GitHub Actions artifact 形式上传，便于调试与验证。

#### Scenario: workflow_dispatch 手动触发后上传 artifact
- **WHEN** 通过 GitHub UI 手动触发 `Release DMG`
- **THEN** 本次 workflow 的 artifacts 中包含 `dmg` 与 `sha256` 文件

## MODIFIED Requirements

<!--
修改已有 requirement 时：
1) 从 openspec/specs/<capability>/spec.md 复制完整 requirement 块（从 `### Requirement:` 到其下所有 scenarios）
2) 粘贴到这里并修改为新行为
-->

## REMOVED Requirements

## RENAMED Requirements

