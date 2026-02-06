import Carbon
import SwiftUI

struct TextBlockSettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var entries: [TextBlockEntry] = []
    @State private var selectedID: UUID?
    @State private var editTitle: String = ""
    @State private var editContent: String = ""

    @State private var isRecordingHotkey = false
    @State private var textBlockHotkey: Hotkey = .textBlockDefault
    @State private var hotkeyError: String?

    var body: some View {
        Form {
            Section("文本块面板快捷键") {
                LabeledContent("快捷键") {
                    HStack(spacing: 10) {
                        Text(textBlockHotkey.displayString).monospacedDigit()
                        Button("修改…") { isRecordingHotkey = true }
                    }
                }

                if let hotkeyError {
                    Text(hotkeyError)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if appState.textBlockHotkeyRegisterStatus != noErr {
                    Text("快捷键可能冲突，请更换组合。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("建议包含 ⌘，避免与应用常用快捷键冲突。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("文本块") {
                HStack(alignment: .top, spacing: 12) {
                    List(selection: $selectedID) {
                        ForEach(entries, id: \.uuid) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title).lineLimit(1)
                                Text(entry.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .tag(entry.uuid)
                        }
                        .onMove(perform: moveRows)
                    }
                    .frame(minWidth: 240, minHeight: 260)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("标题", text: $editTitle)
                            .onSubmit(saveSelection)
                        TextEditor(text: $editContent)
                            .frame(minHeight: 180)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 1))
                        HStack {
                            Button("新建", action: createEntry)
                            Button("删除", role: .destructive, action: deleteSelection).disabled(selectedID == nil)
                            Button("上移", action: moveUp).disabled(selectedID == nil)
                            Button("下移", action: moveDown).disabled(selectedID == nil)
                            Spacer()
                            Button("保存", action: saveSelection).disabled(selectedID == nil)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onDisappear(perform: saveSelection)
        .onChange(of: selectedID) { _ in loadSelectionDraft() }
        .sheet(isPresented: $isRecordingHotkey) {
            TextBlockHotkeyRecorderSheet(
                onCancel: { isRecordingHotkey = false },
                onCapture: handleHotkeyCapture
            )
        }
    }

    private func load() {
        textBlockHotkey = appState.preferences.textBlockHotkey
        entries = (try? appState.textBlockStore.fetchAllBySortOrder()) ?? []
        if selectedID == nil { selectedID = entries.first?.uuid }
        loadSelectionDraft()
    }

    private func loadSelectionDraft() {
        guard let selectedID, let selected = entries.first(where: { $0.uuid == selectedID }) else {
            editTitle = ""
            editContent = ""
            return
        }
        editTitle = selected.title
        editContent = selected.content
    }

    private func createEntry() {
        if let created = try? appState.textBlockStore.create(title: "新文本块", content: "请编辑内容") {
            reload(keep: created.uuid)
            appState.refreshTextBlockPanelEntries()
        }
    }

    private func saveSelection() {
        guard let selectedID else { return }
        guard let _ = try? appState.textBlockStore.update(id: selectedID, title: editTitle, content: editContent) else { return }
        reload(keep: selectedID)
        appState.refreshTextBlockPanelEntries()
    }

    private func deleteSelection() {
        guard let selectedID else { return }
        try? appState.textBlockStore.delete(id: selectedID)
        reload(keep: entries.first(where: { $0.uuid != selectedID })?.uuid)
        appState.refreshTextBlockPanelEntries()
    }

    private func moveRows(from offsets: IndexSet, to destination: Int) {
        try? appState.textBlockStore.move(fromOffsets: offsets, toOffset: destination)
        reload(keep: selectedID)
        appState.refreshTextBlockPanelEntries()
    }

    private func moveUp() {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }), index > 0 else { return }
        moveRows(from: IndexSet(integer: index), to: index - 1)
    }

    private func moveDown() {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }), index < entries.count - 1 else { return }
        moveRows(from: IndexSet(integer: index), to: index + 2)
    }

    private func reload(keep id: UUID?) {
        entries = (try? appState.textBlockStore.fetchAllBySortOrder()) ?? []
        selectedID = id ?? entries.first?.uuid
        loadSelectionDraft()
    }

    private func handleHotkeyCapture(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc
            isRecordingHotkey = false
            return
        }

        let modifiers = carbonModifiers(from: event.modifierFlags)
        let candidate = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        if let error = HotkeyValidation.validateTextBlock(candidate, clipboardHotkey: appState.preferences.hotkey) {
            switch error {
            case .missingCommand:
                hotkeyError = "文本块快捷键必须包含 ⌘。"
            case .conflictsWithClipboard:
                hotkeyError = "不能与剪切板面板快捷键相同。"
            }
            return
        }

        hotkeyError = nil
        textBlockHotkey = candidate
        appState.applyTextBlockHotkey(candidate)
        isRecordingHotkey = false
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

private struct TextBlockHotkeyRecorderSheet: View {
    var onCancel: () -> Void
    var onCapture: (NSEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("按下新的文本块快捷键")
                        .font(.headline)
                    Text("按 Esc 取消；必须包含 ⌘")
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
