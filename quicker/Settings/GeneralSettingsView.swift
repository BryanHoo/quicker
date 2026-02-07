import Carbon
import SwiftUI

struct GeneralSettingsView: View {
    private struct Hint {
        let text: String
        let color: Color
        let symbolName: String
    }

    private enum RecordingTarget: Int, Identifiable {
        case clipboard
        case textBlock

        var id: Int { rawValue }
    }

    @EnvironmentObject private var appState: AppState
    @State private var hotkey: Hotkey = PreferencesKeys.hotkey.defaultValue
    @State private var textBlockHotkey: Hotkey = PreferencesKeys.textBlockHotkey.defaultValue
    @State private var recordingTarget: RecordingTarget?
    @State private var clipboardHotkeyError: String?
    @State private var textBlockHotkeyError: String?
    @StateObject private var launch = LaunchAtLoginService()

    var body: some View {
        SettingsStack {
            SettingsSection("快捷键") {
                hotkeyRow(
                    title: "剪切板面板",
                    hotkeyDisplay: hotkey.displayString,
                    hint: clipboardHint
                ) {
                    recordingTarget = .clipboard
                }

                Divider()

                hotkeyRow(
                    title: "文本块面板",
                    hotkeyDisplay: textBlockHotkey.displayString,
                    hint: textBlockHint
                ) {
                    recordingTarget = .textBlock
                }
            }

            SettingsSection("启动") {
                SettingsRow {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开机自启")
                        Text("登录后自动在后台运行 Quicker。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } trailing: {
                    Toggle("", isOn: Binding(
                        get: { launch.isEnabled },
                        set: { launch.setEnabled($0) }
                    ))
                    .labelsHidden()
                    .onAppear { launch.refresh() }
                }
            }
        }
        .onAppear(perform: load)
        .sheet(item: $recordingTarget) { target in
            HotkeyRecorderSheet(
                title: target == .clipboard ? "按下新的剪切板快捷键" : "按下新的文本块快捷键",
                subtitle: target == .clipboard ? "按 Esc 取消" : "按 Esc 取消（必须包含 ⌘）",
                onCancel: { recordingTarget = nil },
                onCapture: { event in
                    handleHotkeyCapture(event, for: target)
                }
            )
        }
    }

    @ViewBuilder
    private func hotkeyRow(
        title: String,
        hotkeyDisplay: String,
        hint: Hint?,
        action: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SettingsRow {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                    Text("建议使用包含 ⌘ 的组合键")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } trailing: {
                hotkeyEditor(hotkeyDisplay, action: action)
            }

            if let hint {
                Label(hint.text, systemImage: hint.symbolName)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(hint.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule(style: .continuous)
                            .fill(hint.color.opacity(0.12))
                    )
            }
        }
        .padding(.vertical, 1)
    }

    @ViewBuilder
    private func hotkeyEditor(_ hotkeyDisplay: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(hotkeyDisplay)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                )
            Button("修改", action: action)
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("点击后按下新的快捷键")
        }
    }

    private var clipboardHint: Hint? {
        if let clipboardHotkeyError {
            return Hint(text: clipboardHotkeyError, color: .red, symbolName: "xmark.octagon.fill")
        }
        if appState.hotkeyRegisterStatus != noErr {
            return Hint(
                text: "快捷键可能与系统或其他应用冲突，建议换一个组合。",
                color: .orange,
                symbolName: "exclamationmark.triangle.fill"
            )
        }
        return nil
    }

    private var textBlockHint: Hint? {
        if let textBlockHotkeyError {
            return Hint(text: textBlockHotkeyError, color: .red, symbolName: "xmark.octagon.fill")
        }
        if appState.textBlockHotkeyRegisterStatus != noErr {
            return Hint(
                text: "快捷键可能冲突，请更换组合。",
                color: .orange,
                symbolName: "exclamationmark.triangle.fill"
            )
        }
        return nil
    }

    private func load() {
        hotkey = appState.preferences.hotkey
        textBlockHotkey = appState.preferences.textBlockHotkey
    }

    private func handleHotkeyCapture(_ event: NSEvent, for target: RecordingTarget) {
        if event.keyCode == 53 { // Esc
            recordingTarget = nil
            return
        }

        guard event.modifierFlags.contains(.command) else { return }

        let modifiers = carbonModifiers(from: event.modifierFlags)
        let candidate = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)

        switch target {
        case .clipboard:
            if let error = HotkeyValidation.validateClipboard(candidate, textBlockHotkey: textBlockHotkey) {
                switch error {
                case .conflictsWithTextBlock:
                    clipboardHotkeyError = "不能与文本块面板快捷键相同。"
                case .missingCommand, .conflictsWithClipboard:
                    clipboardHotkeyError = "快捷键无效，请重新设置。"
                }
                return
            }
            clipboardHotkeyError = nil
            hotkey = candidate
            appState.applyHotkey(candidate)

        case .textBlock:
            if let error = HotkeyValidation.validateTextBlock(candidate, clipboardHotkey: hotkey) {
                switch error {
                case .missingCommand:
                    textBlockHotkeyError = "文本块快捷键必须包含 ⌘。"
                case .conflictsWithClipboard:
                    textBlockHotkeyError = "不能与剪切板面板快捷键相同。"
                case .conflictsWithTextBlock:
                    textBlockHotkeyError = "快捷键无效，请重新设置。"
                }
                return
            }
            textBlockHotkeyError = nil
            textBlockHotkey = candidate
            appState.applyTextBlockHotkey(candidate)
        }

        recordingTarget = nil
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}

private struct HotkeyRecorderSheet: View {
    var title: String
    var subtitle: String
    var onCancel: () -> Void
    var onCapture: (NSEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.14))
                        .frame(width: 36, height: 36)
                    Image(systemName: "keyboard")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.accentColor.opacity(0.18), lineWidth: 1)
                )
                .frame(height: 64)
                .overlay(
                    Label("正在监听键盘输入…", systemImage: "waveform.path.ecg")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                )

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.cancelAction)
            }

            HotkeyRecorderView { event in
                onCapture(event)
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(16)
        .frame(width: 440, height: 214)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.04),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}
