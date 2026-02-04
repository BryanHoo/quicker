import AppKit
import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var viewModel: ClipboardPanelViewModel
    var onClose: () -> Void
    var onPaste: (String) -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        ZStack {
            KeyEventHandlingView { event in
                handleKeyDown(event)
            }
            VStack(alignment: .leading, spacing: 10) {
                header
                content
            }
            .padding(16)
            .frame(width: 520, height: 240)
        }
    }

    private var header: some View {
        HStack {
            Text("Clipboard")
                .font(.headline)
            Spacer()
            Text(pageLabel)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var pageLabel: String {
        let total = viewModel.pageCount
        guard total > 0 else { return "0/0" }
        return "\(viewModel.pageIndex + 1)/\(total)"
    }

    private var content: some View {
        Group {
            if viewModel.entries.isEmpty {
                Text("暂无历史记录")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(viewModel.visibleEntries.enumerated()), id: \.offset) { idx, text in
                        row(text: text, isSelected: idx == viewModel.selectedIndexInPage)
                    }
                    Spacer()
                }
            }
        }
    }

    private func row(text: String, isSelected: Bool) -> some View {
        Text(text)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.18) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc
            onClose()
            return
        }

        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
            onOpenSettings()
            return
        }

        if event.keyCode == 36 { // Return
            if let text = viewModel.selectedText { onPaste(text) }
            return
        }
        switch event.keyCode {
        case 125: viewModel.moveSelectionDown() // ↓
        case 126: viewModel.moveSelectionUp() // ↑
        case 123: viewModel.previousPage() // ←
        case 124: viewModel.nextPage() // →
        default:
            break
        }

        if event.modifierFlags.contains(.command) {
            if let number = Int(event.charactersIgnoringModifiers ?? ""), (1...viewModel.pageSize).contains(number) {
                if let text = viewModel.textForCmdNumber(number) { onPaste(text) }
            }
        }
    }
}

