import AppKit
import SwiftUI

struct TextBlockPanelView: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

    @ObservedObject var viewModel: TextBlockPanelViewModel
    @Environment(\.openSettings) private var openSettings
    var onClose: () -> Void
    var onInsert: (TextBlockPanelEntry) -> Void

    var body: some View {
        ZStack {
            KeyEventHandlingView { handleKeyDown($0) }
            VStack(alignment: .leading, spacing: 0) {
                header
                divider
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                divider
                footer
            }
            .padding(Theme.containerPadding)
            .frame(width: Theme.size.width, height: Theme.size.height, alignment: .topLeading)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    private var header: some View {
        HStack {
            Image(systemName: "text.bubble")
            Text("文本块")
            Spacer()
            Text("⌘, 设置").foregroundStyle(.secondary)
        }
        .font(.system(size: 14, weight: .semibold))
        .padding(.bottom, 10)
    }

    private var content: some View {
        Group {
            if viewModel.entries.isEmpty {
                Text("暂无文本块，请到设置中新增")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.visibleEntries.enumerated()), id: \.offset) { idx, entry in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(entry.title).lineLimit(1)
                                    Spacer()
                                    Text("⌘\(idx + 1)")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                                Text(entry.content)
                                    .font(.system(size: 12))
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(idx == viewModel.selectedIndexInPage ? Color.accentColor.opacity(0.14) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .onTapGesture { viewModel.selectIndexInPage(idx) }
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(.vertical, 10)
    }

    private var footer: some View {
        HStack {
            Text("Esc 关闭")
            Text("Enter 插入")
            Text("↑↓ 选择")
            Text("←→ 翻页")
            Spacer()
            Text(pageLabel).monospacedDigit().foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .padding(.top, 10)
    }

    private var pageLabel: String {
        let total = viewModel.pageCount
        guard total > 0 else { return "0/0" }
        return "\(viewModel.pageIndex + 1)/\(total)"
    }

    private var divider: some View {
        Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 1)
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 {
            onClose()
            return
        }

        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
            onClose()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            return
        }

        if event.keyCode == 36 {
            if let entry = viewModel.selectedEntry { onInsert(entry) }
            return
        }

        switch event.keyCode {
        case 125: viewModel.moveSelectionDown()
        case 126: viewModel.moveSelectionUp()
        case 123: viewModel.previousPage()
        case 124: viewModel.nextPage()
        default: break
        }

        if event.modifierFlags.contains(.command),
           let number = Int(event.charactersIgnoringModifiers ?? ""),
           (1...viewModel.pageSize).contains(number),
           let entry = viewModel.entryForCmdNumber(number) {
            onInsert(entry)
        }
    }
}
