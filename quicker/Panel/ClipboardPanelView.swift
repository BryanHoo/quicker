import AppKit
import Foundation
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
                        ForEach(Array(viewModel.visibleEntries.enumerated()), id: \.element.id) { idx, entry in
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
            if let entry = viewModel.selectedEntry { onPaste(entry) }
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
            if let entry = viewModel.entryForCmdNumber(number) { onPaste(entry) }
            return true
        }
    }
}

private struct ClipboardEntryRow: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

    let entry: ClipboardPanelEntry
    let cmdNumber: Int
    let isSelected: Bool
    var onSelect: () -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    private var createdAtText: String {
        Self.timeFormatter.string(from: entry.createdAt)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                leading

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(entry.previewText)
                            .font(Theme.rowTextFont)
                            .lineLimit(1)
                            .truncationMode(entry.kind == .image ? .middle : .tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .help(entry.previewText)

                        Text("⌘\(cmdNumber)")
                            .font(Theme.rowCommandFont)
                            .foregroundStyle(.secondary)
                    }

                    Text(createdAtText)
                        .font(Theme.rowMetaFont)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, Theme.rowVerticalPadding)
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
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var leading: some View {
        switch entry.kind {
        case .image:
            ClipboardImageThumbnail(imagePath: entry.imagePath)
        case .rtf:
            ClipboardKindIcon(systemName: "doc.richtext")
        case .text:
            ClipboardKindIcon(systemName: "text.alignleft")
        }
    }
}

private struct ClipboardImageThumbnail: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

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
        .frame(width: Theme.rowLeadingSize, height: Theme.rowLeadingSize)
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

private struct ClipboardKindIcon: View {
    private typealias Theme = QuickerTheme.ClipboardPanel

    let systemName: String

    var body: some View {
        ZStack {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
        }
        .frame(width: Theme.rowLeadingSize, height: Theme.rowLeadingSize)
        .background(.quaternary.opacity(0.2), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
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
