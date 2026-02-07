# GitHub Actions Release DMG Implementation Plan

> **REQUIRED SUB-SKILL:** Use `codespec-test-driven-development` discipline for every behavior change.

**Goal:** push tag（`v*`）时自动构建 `quicker.app`，打包为未签名/未公证的 `dmg` 并发布到 GitHub Releases（同时上传 `sha256`）。

**Architecture:** `.github/workflows/release-dmg.yml` 触发与发布；`scripts/ci/package_dmg.sh` 负责从 `xcodebuild` 产物生成 `dmg` 与 `sha256`，输出到 `build/artifacts/`。

**Tech Stack:** `xcodebuild`, `hdiutil`, `shasum`, GitHub Actions (`actions/checkout`, `softprops/action-gh-release`, `actions/upload-artifact`)

---

## 0. Preparation

- [ ] 0.1 Identify verification command(s) for this repo
  - Run:
    - `xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Release -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" build`
    - `VERSION=v0.0.0 bash scripts/ci/package_dmg.sh`
  - Expected:
    - `xcodebuild` exit 0
    - 生成 `build/artifacts/quicker-v0.0.0.dmg` 与 `build/artifacts/quicker-v0.0.0.dmg.sha256`

- [ ] 0.2 Identify formatting/lint command(s) if applicable
  - Notes: 本变更主要为脚本与 YAML，暂不引入额外 lint。

## 1. Scenario-driven TDD tasks

### Scenario: github-release-dmg/Tag 触发 Release DMG 构建与发布/Push tag `v1.0.0` 后生成并发布 release 附件

- [ ] 1.1 [TDD][RED] 新增 workflow 触发与发布骨架（先不接入真实打包产物）
  - Files:
    - Create: `.github/workflows/release-dmg.yml`
  - Run: `cat .github/workflows/release-dmg.yml`
  - Expected: 文件存在且包含 `on: push: tags: - 'v*'`

- [ ] 1.2 [TDD][VERIFY_RED] 在本地跑打包命令，确认当前尚未产出 `dmg`
  - Run: `VERSION=v0.0.0 bash scripts/ci/package_dmg.sh`
  - Expected: FAIL（`scripts/ci/package_dmg.sh: No such file or directory` 或退出码非 0）

- [ ] 1.3 [TDD][GREEN] 实现构建与 DMG 打包脚本，并在 workflow 中调用
  - Files:
    - Create: `scripts/ci/package_dmg.sh`
    - Modify: `.github/workflows/release-dmg.yml`

- [ ] 1.4 [TDD][VERIFY_GREEN] 本地构建并运行打包脚本，确认产物生成且 `sha256` 可校验
  - Run:
    - `xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Release -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" build`
    - `VERSION=v0.0.0 bash scripts/ci/package_dmg.sh`
    - `cd build/artifacts && shasum -a 256 -c quicker-v0.0.0.dmg.sha256`
  - Expected:
    - `build/artifacts/quicker-v0.0.0.dmg` 存在且非空
    - `shasum: quicker-v0.0.0.dmg: OK`

- [ ] 1.5 [TDD][REFACTOR] 清理脚本与 workflow 细节（命名、输出目录、错误信息）
  - Notes: 保持行为不变，提升可读性与可维护性。

### Scenario: github-release-dmg/workflow_dispatch 支持手动验证（不发布 release）/workflow_dispatch 手动触发后上传 artifact

- [ ] 1.6 [TDD][RED] 在 workflow 中加入 `workflow_dispatch`，并让发布 release 步骤仅在 tag 触发时运行
  - Files:
    - Modify: `.github/workflows/release-dmg.yml`

- [ ] 1.7 [TDD][VERIFY_RED] 静态检查 workflow 条件分支存在
  - Run: `grep -n \"workflow_dispatch\" -n .github/workflows/release-dmg.yml && grep -n \"refs/tags/\" -n .github/workflows/release-dmg.yml`
  - Expected: 两条 grep 都有匹配行（exit 0）

- [ ] 1.8 [TDD][GREEN] 增加 `actions/upload-artifact` 上传 `dmg` 与 `sha256`（无论是否发布 release）
  - Files:
    - Modify: `.github/workflows/release-dmg.yml`

- [ ] 1.9 [TDD][VERIFY_GREEN] 静态检查 artifact 上传步骤存在
  - Run: `grep -n \"actions/upload-artifact\" -n .github/workflows/release-dmg.yml`
  - Expected: grep 匹配（exit 0）

- [ ] 1.10 [TDD][REFACTOR] 统一变量命名与输出目录约定
  - Notes: 例如 `build/DerivedData`、`build/artifacts`、`VERSION` 处理一致。

## 2. Integration & verification

- [ ] 2.1 Run a clean local build (Release, no signing)
  - Run: `xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Release -derivedDataPath build/DerivedData CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" clean build`
  - Expected: exit 0

- [ ] 2.2 Validate packaging output one more time
  - Run: `VERSION=v0.0.0 bash scripts/ci/package_dmg.sh && ls -la build/artifacts`
  - Expected: `quicker-v0.0.0.dmg` 与 `quicker-v0.0.0.dmg.sha256` 存在

## 3. Spec sync checklist

- [ ] 3.1 Confirm tasks.md checkboxes reflect actual work done
- [ ] 3.2 Confirm specs/design/proposal match implementation reality

