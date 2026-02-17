import AppKit
import SwiftUI

struct TextBlockPanelView: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

    @ObservedObject var viewModel: TextBlockPanelViewModel
    @Environment(\.openSettings) private var openSettings
    @FocusState private var isSearchFocused: Bool
    var onClose: () -> Void
    var onInsert: (TextBlockPanelEntry) -> Void

    var body: some View {
        ZStack {
            KeyEventHandlingView { handleKeyDown($0) }

            PanelKeyCommandMonitor(
                panelIdentifier: PanelWindowIdentifier.textBlockPanel,
                pageSize: viewModel.pageSize,
                onCommand: handlePanelCommand
            )

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
        .onAppear {
            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { notification in
            guard let window = notification.object as? NSWindow,
                  window.identifier == PanelWindowIdentifier.textBlockPanel
            else { return }

            DispatchQueue.main.async {
                isSearchFocused = true
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                Image(systemName: "text.bubble")
                Text("文本块")
                Spacer()
                Text("⌘, 设置").foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("搜索", text: $viewModel.searchQuery)
                    .font(.system(size: 13))
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)

                if viewModel.searchQuery.isEmpty == false {
                    Button {
                        viewModel.searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("清除")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.quaternary.opacity(Theme.keyCapBackgroundOpacity), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(Theme.keyCapBorderOpacity), lineWidth: 1)
            )
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
            } else if viewModel.filteredEntries.isEmpty {
                if #available(macOS 14.0, *) {
                    ContentUnavailableView("无匹配结果", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("无匹配结果")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.visibleEntries.enumerated()), id: \.element.id) { idx, entry in
                            Button { viewModel.selectIndexInPage(idx) } label: {
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
                            }
                            .buttonStyle(.plain)
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

    private func handleKeyDown(_ event: NSEvent) -> Bool {
        guard
            let cmd = PanelKeyCommand.interpret(
                .init(
                    keyCode: UInt16(event.keyCode),
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                    isCommandDown: event.modifierFlags.contains(.command)
                ),
                pageSize: viewModel.pageSize
            )
        else {
            return false
        }

        return handlePanelCommand(cmd)
    }

    private func handlePanelCommand(_ cmd: PanelKeyCommand) -> Bool {
        switch cmd {
        case .close:
            onClose()
            return true
        case .openSettings:
            onClose()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            return true
        case .confirm:
            if let entry = viewModel.selectedEntry { onInsert(entry) }
            return true
        case .moveUp:
            viewModel.moveSelectionUp()
            return true
        case .moveDown:
            viewModel.moveSelectionDown()
            return true
        case .previousPage:
            viewModel.previousPage()
            return true
        case .nextPage:
            viewModel.nextPage()
            return true
        case .pasteCmdNumber(let number):
            if let entry = viewModel.entryForCmdNumber(number) { onInsert(entry) }
            return true
        }
    }
}
