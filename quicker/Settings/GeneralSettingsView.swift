import Carbon
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hotkey: Hotkey = PreferencesKeys.hotkey.defaultValue
    @State private var isRecordingHotkey = false
    @StateObject private var launch = LaunchAtLoginService()

    var body: some View {
        Form {
            Section("唤出") {
                LabeledContent("快捷键") {
                    HStack(spacing: 10) {
                        Text(hotkeyDisplay)
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                        Button("修改…") { isRecordingHotkey = true }
                    }
                }

                if appState.hotkeyRegisterStatus != noErr {
                    Text("快捷键可能与系统或其他应用冲突，建议换一个组合。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("建议包含 ⌘，避免与常用输入快捷键冲突。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("启动") {
                Toggle("开机自启", isOn: Binding(
                    get: { launch.isEnabled },
                    set: { launch.setEnabled($0) }
                ))
                .onAppear { launch.refresh() }
            }
        }
        .formStyle(.grouped)
        .onAppear { hotkey = appState.preferences.hotkey }
        .sheet(isPresented: $isRecordingHotkey) {
            HotkeyRecorderSheet(
                onCancel: { isRecordingHotkey = false },
                onCapture: { event in
                    if event.keyCode == 53 { // Esc
                        isRecordingHotkey = false
                        return
                    }

                    guard event.modifierFlags.contains(.command) else { return }

                    let modifiers = carbonModifiers(from: event.modifierFlags)
                    let captured = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                    hotkey = captured
                    appState.applyHotkey(captured)
                    isRecordingHotkey = false
                }
            )
        }
    }

    private var hotkeyDisplay: String {
        if hotkey == .default { return "⌘⇧V" }
        return "键码 \(hotkey.keyCode)"
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
    var onCancel: () -> Void
    var onCapture: (NSEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("按下新的快捷键")
                        .font(.headline)
                    Text("按 Esc 取消；建议包含 ⌘")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .frame(height: 60)
                .overlay(
                    Text("正在监听键盘输入…")
                        .foregroundStyle(.secondary)
                )

            HStack {
                Spacer()
                Button("取消") { onCancel() }
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
        .frame(width: 440, height: 210)
    }
}
