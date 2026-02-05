import AppKit
import ImageIO
import SwiftUI

struct ClipboardPanelView: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

    @ObservedObject var viewModel: ClipboardPanelViewModel
    @Environment(\.openSettings) private var openSettings
    var onClose: () -> Void
    var onPaste: (ClipboardPanelEntry) -> Void
    private let sectionSpacing: CGFloat = Theme.sectionSpacing

    var body: some View {
        ZStack {
            KeyEventHandlingView { event in
                handleKeyDown(event)
            }

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.bottom, sectionSpacing)

                dividerLine

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.vertical, sectionSpacing)

                dividerLine

                footer
                    .padding(.top, sectionSpacing)
            }
            .padding(Theme.containerPadding)
            .frame(width: Theme.size.width, height: Theme.size.height, alignment: .topLeading)
            .background(Theme.background)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(Theme.borderOpacity), lineWidth: 1)
            )
            .shadow(
                color: .black.opacity(Theme.shadowOpacity),
                radius: Theme.shadowRadius,
                x: Theme.shadowOffset.width,
                y: Theme.shadowOffset.height
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(Theme.headerFont)
                .foregroundStyle(.secondary)
            Text("剪贴板")
                .font(Theme.headerFont)
            Spacer()
            KeyHint(symbol: "⌘,", description: "设置")
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
                if #available(macOS 14.0, *) {
                    ContentUnavailableView("暂无历史记录", systemImage: "doc.on.clipboard")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("暂无历史记录")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(viewModel.visibleEntries.enumerated()), id: \.offset) { idx, entry in
                            ClipboardEntryRow(
                                entry: entry,
                                cmdNumber: idx + 1,
                                isSelected: idx == viewModel.selectedIndexInPage,
                                onSelect: {
                                    viewModel.selectIndexInPage(idx)
                                }
                            )
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .scrollContentBackground(.hidden)
                .animation(.easeOut(duration: 0.12), value: viewModel.selectedIndexInPage)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 14) {
            KeyHint(symbol: "Esc", description: "关闭")
            KeyHint(symbol: "Enter", description: "粘贴")
            KeyHint(symbol: "↑↓", description: "选择")
            KeyHint(symbol: "←→", description: "翻页")
            Spacer()
            Text(pageLabel)
                .font(Theme.pageLabelFont)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary.opacity(Theme.pagePillBackgroundOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.primary.opacity(Theme.dividerOpacity))
            .frame(height: 1)
    }

    private func handleKeyDown(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc
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

        if event.keyCode == 36 { // Return
            if let entry = viewModel.selectedEntry { onPaste(entry) }
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
                if let entry = viewModel.entryForCmdNumber(number) { onPaste(entry) }
            }
        }
    }
}

private struct ClipboardEntryRow: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

    let entry: ClipboardPanelEntry
    let cmdNumber: Int
    let isSelected: Bool
    var onSelect: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if entry.kind == .image {
                ClipboardImageThumbnail(imagePath: entry.imagePath)
            }

            Text(entry.previewText)
                .font(Theme.rowTextFont)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("⌘\(cmdNumber)")
                .font(Theme.rowCommandFont)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 10)
        .background(
            ZStack {
                if isSelected {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(Color.accentColor.opacity(Theme.selectedFillOpacity))
                        .overlay(
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(Color.accentColor.opacity(Theme.selectedBorderOpacity), lineWidth: 1)
                        )
                }
            }
        )
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture { onSelect() }
    }
}

private struct ClipboardImageThumbnail: View {
    let imagePath: String?

    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 32, height: 32)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .task(id: imagePath) {
            thumbnail = Self.loadThumbnail(relativePath: imagePath)
        }
    }

    private static func loadThumbnail(relativePath: String?) -> NSImage? {
        guard let relativePath else { return nil }

        let url = ClipboardAssetStore.defaultBaseURL().appendingPathComponent(relativePath, isDirectory: false)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let thumbOpts: [CFString: Any] = [
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: 64,
        ]

        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, thumbOpts as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }
}

private struct KeyHint: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

    let symbol: String
    let description: String

    var body: some View {
        HStack(spacing: 6) {
            Text(symbol)
                .font(Theme.hintSymbolFont)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary.opacity(Theme.keyCapBackgroundOpacity), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(Theme.keyCapBorderOpacity), lineWidth: 1)
                )

            Text(description)
                .font(Theme.hintTextFont)
                .foregroundStyle(.secondary)
        }
    }
}
