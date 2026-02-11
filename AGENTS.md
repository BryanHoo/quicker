# Repository Guidelines

## 项目结构与模块组织
- `quicker/`：主应用源码（Swift 5，SwiftUI 为主，含少量 AppKit 交互），按功能拆分目录：`Clipboard/`、`Panel/`、`Paste/`、`Hotkey/`、`Settings/` 等。
- `quicker/Assets.xcassets/`：应用图标与资源。
- `quickerTests/`：单元/逻辑测试（XCTest），文件通常为 `*Tests.swift`。
- `quickerUITests/`：UI 测试（XCUITest）。
- `quicker.xcodeproj/`：Xcode 工程配置（新增依赖/target 时会修改 `quicker.xcodeproj/project.pbxproj`）。

## 构建、测试与本地运行
- 在 Codex 环境下优先使用 `xc-build` / `xc-testing`；以下为命令行回退（`xcodebuild`）示例。
- 打开工程：`open quicker.xcodeproj`
- 清理构建产物：`xcodebuild -project quicker.xcodeproj -scheme quicker clean`
- Debug 构建：`xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Debug build`
- Release 构建：`xcodebuild -project quicker.xcodeproj -scheme quicker -configuration Release build`
- 运行全部测试（macOS）：`xcodebuild test -project quicker.xcodeproj -scheme quicker -destination 'platform=macOS'`
- 仅跑单个测试类：`xcodebuild test -project quicker.xcodeproj -scheme quicker -only-testing:quickerTests/ClipboardStoreTests`
- 仅跑 UI 测试 target：`xcodebuild test -project quicker.xcodeproj -scheme quicker -only-testing:quickerUITests`
- 保存测试结果便于分享：`xcodebuild test -project quicker.xcodeproj -scheme quicker -destination 'platform=macOS' -resultBundlePath /tmp/quicker.xcresult`

## 代码风格与命名约定
- 保持与现有代码一致：4 空格缩进、优先小函数与清晰命名，遵循 Swift API Design Guidelines。
- 命名：类型/协议用 `UpperCamelCase`；方法/变量用 `lowerCamelCase`；文件名与主要类型同名（如 `ClipboardStore.swift`）。
- 仓库当前未内置 `SwiftLint`/`SwiftFormat` 配置；提交前请用 Xcode 的 Format/Indent 保持风格统一。

## 测试指南
- 新功能优先补齐 `quickerTests/` 的逻辑覆盖；涉及交互与回归场景再补 `quickerUITests/`。
- 测试方法以 `test...` 开头；新增用例尽量定位到对应模块（例如剪贴板逻辑放在 `Clipboard*Tests.swift` 附近）。

## 配置、安全与系统权限
- 这是 macOS 菜单栏应用，运行/测试可能触发系统权限（剪贴板、辅助功能、输入监控等）。涉及权限或 capability 变更时，请通过 Xcode 的 Signing & Capabilities 修改，并在 PR 描述中明确说明验证步骤。
- 部署目标为 `MACOSX_DEPLOYMENT_TARGET = 14.0`；引入新 API 前请确认可用性与降级策略。
- 不要提交本机生成文件（例如 DerivedData、`.DS_Store`）。需要新增忽略项时更新 `.gitignore` 并说明原因。

## 提交与 PR 规范
- 提交信息遵循 Conventional Commits：`type(scope): summary`（例如 `feat(settings): ...`、`fix(panel): ...`、`refactor(hotkey): ...`）。
- PR 请包含：变更动机与方案、验证方式（至少说明是否跑过 `xcodebuild test`）、UI 变更附截图/录屏、关联 issue（如有）。

## Agent 额外提示（可选）
- 默认用简体中文沟通；不要翻译/改写代码标识符、命令与路径。
- 修改尽量最小化、可回滚。
- 工具优先级：优先用 xcodebuildmcp-cli 命令执行 xcode 相关操作；当工具不可用或需要纯 CLI 时回退到 `xcodebuild` 等命令。
