import Carbon
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var hotkey: Hotkey = PreferencesKeys.hotkey.defaultValue
    @State private var isRecordingHotkey = false

    var body: some View {
        Form {
            Section("唤出快捷键") {
                HStack {
                    Text("当前：\(hotkeyDisplay)")
                    Spacer()
                    Button("修改…") { isRecordingHotkey = true }
                }
                if appState.hotkeyRegisterStatus != noErr {
                    Text("可能与系统/其他应用冲突，建议换一个组合。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("开机自启") {
                Text("MVP：下一步接入 SMAppService")
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { hotkey = appState.preferences.hotkey }
        .sheet(isPresented: $isRecordingHotkey) {
            VStack(alignment: .leading, spacing: 12) {
                Text("按下新的快捷键（建议包含 ⌘）").font(.headline)
                Text("按 Esc 取消").foregroundStyle(.secondary)
                HotkeyRecorderView { event in
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
                Spacer()
            }
            .padding(16)
            .frame(width: 420, height: 180)
        }
    }

    private var hotkeyDisplay: String {
        if hotkey == .default { return "⌘⇧V" }
        return "keyCode \(hotkey.keyCode)"
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

