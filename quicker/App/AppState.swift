import AppKit
import Combine
import Carbon
import Foundation
import SwiftData

@MainActor
final class AppState: ObservableObject {
    let modelContainer: ModelContainer
    let preferences: PreferencesStore
    let ignoreAppStore: IgnoreAppStore
    let clipboardStore: ClipboardStore
    let pasteService: PasteService
    let panelViewModel: ClipboardPanelViewModel
    let panelController: PanelController
    let clipboardMonitor: ClipboardMonitor
    let hotkeyManager: HotkeyManager
    let toast: ToastPresenter

    @Published private(set) var hotkeyRegisterStatus: OSStatus = noErr

    init() {
        let schema = Schema([ClipboardEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let modelContainer = try! ModelContainer(for: schema, configurations: [config])

        let preferences = PreferencesStore()
        let ignoreAppStore = IgnoreAppStore()
        let clipboardStore = ClipboardStore(modelContainer: modelContainer, preferences: preferences)
        let pasteService = PasteService()
        let toast = ToastPresenter()

        let panelViewModel = ClipboardPanelViewModel(pageSize: 5)
        let panelController = PanelController(viewModel: panelViewModel) { text, previousApp in
            if SystemAccessibilityPermission().isProcessTrusted(promptIfNeeded: false) {
                previousApp?.activate(options: [])
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [pasteService] in
                    _ = pasteService.paste(text: text)
                }
            } else {
                _ = pasteService.paste(text: text)
                toast.show(message: "未开启辅助功能，已复制到剪贴板（可手动 ⌘V）")
            }
        }

        let clipboardMonitor = ClipboardMonitor(
            pasteboard: SystemPasteboardClient(),
            frontmostAppProvider: SystemFrontmostAppProvider(),
            logic: ClipboardMonitorLogic(ignoreAppStore: ignoreAppStore, clipboardStore: clipboardStore)
        )

        let hotkeyManager = HotkeyManager {
            let items = (try? clipboardStore.fetchLatest(limit: 500)) ?? []
            panelViewModel.setEntries(Self.makePanelEntries(from: items))
            panelController.toggle()
        }

        self.modelContainer = modelContainer
        self.preferences = preferences
        self.ignoreAppStore = ignoreAppStore
        self.clipboardStore = clipboardStore
        self.pasteService = pasteService
        self.toast = toast
        self.panelViewModel = panelViewModel
        self.panelController = panelController
        self.clipboardMonitor = clipboardMonitor
        self.hotkeyManager = hotkeyManager
    }

    func start() {
        clipboardMonitor.start()
        hotkeyRegisterStatus = hotkeyManager.register(preferences.hotkey)
    }

    func togglePanel() {
        refreshPanelEntries()
        panelController.toggle()
    }

    func refreshPanelEntries() {
        let items = (try? clipboardStore.fetchLatest(limit: 500)) ?? []
        panelViewModel.setEntries(Self.makePanelEntries(from: items))
    }

    func applyHotkey(_ hotkey: Hotkey) {
        preferences.hotkey = hotkey
        hotkeyRegisterStatus = hotkeyManager.register(hotkey)
    }

    func pasteFromPanel(text: String, previousApp: NSRunningApplication?) {
        if SystemAccessibilityPermission().isProcessTrusted(promptIfNeeded: false) {
            previousApp?.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [pasteService] in
                _ = pasteService.paste(text: text)
            }
        } else {
            _ = pasteService.paste(text: text)
            toast.show(message: "未开启辅助功能，已复制到剪贴板（可手动 ⌘V）")
        }
    }

    func confirmAndClearHistory() {
        let alert = NSAlert()
        alert.messageText = "确认清空所有历史？"
        alert.informativeText = "此操作不可撤销。"
        alert.addButton(withTitle: "清空")
        alert.addButton(withTitle: "取消")
        if alert.runModal() == .alertFirstButtonReturn {
            try? clipboardStore.clear()
            refreshPanelEntries()
        }
    }
}

private extension AppState {
    static func makePanelEntries(from items: [ClipboardEntry]) -> [ClipboardPanelEntry] {
        items.map { entry in
            switch ClipboardEntryKind(raw: entry.kindRaw) {
            case .text:
                ClipboardPanelEntry(kind: .text, previewText: entry.text, rtfData: nil, imagePath: nil)
            case .rtf:
                ClipboardPanelEntry(kind: .rtf, previewText: entry.text, rtfData: entry.rtfData, imagePath: nil)
            case .image:
                ClipboardPanelEntry(kind: .image, previewText: "图片", rtfData: nil, imagePath: entry.imagePath)
            }
        }
    }
}
