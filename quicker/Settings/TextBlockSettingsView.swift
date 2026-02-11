import AppKit
import SwiftUI

struct TextBlockSettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var entries: [TextBlockEntry] = []
    @State private var selectedID: UUID?
    @State private var panelError: String?

    @State private var pendingDeleteID: UUID?
    @State private var isConfirmingDelete = false

    @State private var isEditorPresented = false
    @State private var editingID: UUID?
    @State private var draftTitle = ""
    @State private var draftContent = ""
    @State private var draftError: String?

    var body: some View {
        SettingsStack {
            listPanel
        }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .onAppear(perform: load)
            .sheet(isPresented: $isEditorPresented, content: editorSheet)
            .confirmationDialog("删除这个文本块？", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("删除", role: .destructive, action: confirmDelete)
                Button("取消", role: .cancel) {}
            } message: {
                if let pendingDeleteEntry {
                    Text("“\(pendingDeleteEntry.title)” 删除后无法恢复。")
                } else {
                    Text("删除后无法恢复。")
                }
            }
    }

    private var listPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Label("文本块列表", systemImage: "list.bullet.rectangle")
                        .font(.headline)
                    Text("常用模板可快速插入到当前应用。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: beginCreate) {
                    Label("新增", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .keyboardShortcut("n", modifiers: [.command])
            }

            if entries.isEmpty {
                emptyListState
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(entries, id: \.uuid) { entry in
                            TextBlockListCard(
                                entry: entry,
                                isSelected: selectedID == entry.uuid,
                                onSelect: { selectedID = entry.uuid },
                                onEdit: { beginEdit(id: entry.uuid) },
                                onDelete: { requestDelete(id: entry.uuid) }
                            )
                        }
                    }
                    .padding(.vertical, 1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            HStack(alignment: .center, spacing: 10) {
                if let panelError {
                    Label(panelError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                } else {
                    Text("\(entries.count) 条文本块")
                }

                Spacer()

                HStack(spacing: 8) {
                    Button(action: moveUp) {
                        Label("上移", systemImage: "arrow.up")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .help("上移")
                    .disabled(canMoveUp == false)

                    Button(action: moveDown) {
                        Label("下移", systemImage: "arrow.down")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(.bordered)
                    .help("下移")
                    .disabled(canMoveDown == false)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .settingsModuleCard()
    }

    private var emptyListState: some View {
        VStack(spacing: 9) {
            Spacer(minLength: 16)
            Image(systemName: "text.bubble")
                .font(.system(size: 24, weight: .regular))
                .foregroundStyle(.secondary)
            Text("还没有文本块")
                .font(.headline)
            Text("点击“新增”创建文本块。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 16)
    }

    private var pendingDeleteEntry: TextBlockEntry? {
        guard let pendingDeleteID else { return nil }
        return entries.first(where: { $0.uuid == pendingDeleteID })
    }

    private var canMoveUp: Bool {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }) else { return false }
        return index > 0
    }

    private var canMoveDown: Bool {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }) else { return false }
        return index < entries.count - 1
    }

    private var canSubmitDraft: Bool {
        draftContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    @ViewBuilder
    private func editorSheet() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(editingID == nil ? "新增文本块" : "编辑文本块")
                        .font(.title3.weight(.semibold))
                    Text("留空标题时会自动取正文首行。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("标题")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("留空会自动使用正文首行", text: $draftTitle)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("内容")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draftContent)
                    .font(.body)
                    .frame(minHeight: 200)
                    .padding(8)
                    .settingsCardContainer()
            }

            if let draftError {
                Label(draftError, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("取消", role: .cancel, action: dismissEditor)
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(action: saveDraft) {
                    Label(editingID == nil ? "创建" : "保存", systemImage: "checkmark")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .disabled(canSubmitDraft == false)
            }
        }
        .padding(18)
        .frame(width: 520, height: 410, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.06),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func load() {
        entries = (try? appState.textBlockStore.fetchAllBySortOrder()) ?? []
        panelError = nil
        if let selectedID, entries.contains(where: { $0.uuid == selectedID }) {
            self.selectedID = selectedID
        } else {
            selectedID = entries.first?.uuid
        }
    }

    private func beginCreate() {
        editingID = nil
        draftTitle = ""
        draftContent = ""
        draftError = nil
        panelError = nil
        isEditorPresented = true
    }

    private func beginEdit(id: UUID) {
        guard let entry = entries.first(where: { $0.uuid == id }) else {
            panelError = "当前文本块不存在，请刷新后重试。"
            return
        }
        panelError = nil
        selectedID = id
        editingID = id
        draftTitle = entry.title
        draftContent = entry.content
        draftError = nil
        isEditorPresented = true
    }

    private func dismissEditor() {
        draftError = nil
        isEditorPresented = false
    }

    private func saveDraft() {
        do {
            if let editingID {
                try appState.textBlockStore.update(id: editingID, title: draftTitle, content: draftContent)
                reload(keep: editingID)
            } else {
                let created = try appState.textBlockStore.create(title: draftTitle, content: draftContent)
                reload(keep: created.uuid)
            }
            panelError = nil
            draftError = nil
            isEditorPresented = false
            appState.refreshTextBlockPanelEntries()
        } catch let error as TextBlockStoreError {
            draftError = editorMessage(for: error)
        } catch {
            draftError = "保存失败，请稍后重试。"
        }
    }

    private func requestDelete(id: UUID?) {
        guard let id else { return }
        pendingDeleteID = id
        isConfirmingDelete = true
    }

    private func confirmDelete() {
        guard let pendingDeleteID else { return }
        do {
            try appState.textBlockStore.delete(id: pendingDeleteID)
            reload(keep: entries.first(where: { $0.uuid != pendingDeleteID })?.uuid)
            panelError = nil
            appState.refreshTextBlockPanelEntries()
        } catch {
            panelError = "删除失败，请稍后重试。"
        }
        self.pendingDeleteID = nil
    }

    private func moveRows(from offsets: IndexSet, to destination: Int) {
        do {
            try appState.textBlockStore.move(fromOffsets: offsets, toOffset: destination)
            reload(keep: selectedID)
            panelError = nil
            appState.refreshTextBlockPanelEntries()
        } catch {
            panelError = "排序失败，请稍后重试。"
        }
    }

    private func moveUp() {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }), index > 0 else { return }
        moveRows(from: IndexSet(integer: index), to: index - 1)
    }

    private func moveDown() {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }), index < entries.count - 1 else { return }
        moveRows(from: IndexSet(integer: index), to: index + 2)
    }

    private func editorMessage(for error: TextBlockStoreError) -> String {
        switch error {
        case .emptyContent:
            return "内容不能为空。"
        case .notFound:
            return "当前文本块不存在，请重新选择。"
        }
    }

    private func reload(keep id: UUID?) {
        entries = (try? appState.textBlockStore.fetchAllBySortOrder()) ?? []
        if let id, entries.contains(where: { $0.uuid == id }) {
            selectedID = id
        } else {
            selectedID = entries.first?.uuid
        }
    }

}

private struct TextBlockListCard: View {
    let entry: TextBlockEntry
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var previewText: String {
        let flattened = entry.content.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if flattened.isEmpty {
            return "（空内容）"
        }
        return String(flattened.prefix(80))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(entry.title)
                    .font(.headline.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text(entry.updatedAt, format: .dateTime.hour().minute())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Text(previewText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction { onSelect() }
    }

    private var actionButtons: some View {
        VStack(spacing: 6) {
            Button(action: onEdit) {
                Label("编辑", systemImage: "square.and.pencil")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("编辑")

            Button(role: .destructive, action: onDelete) {
                Label("删除", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("删除")
        }
        .foregroundStyle(.secondary)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            summary
            actionButtons
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.30) : Color.white.opacity(0.22), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onSelect)
    }
}
