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
    let textBlockStore: TextBlockStore
    let pasteService: PasteService
    let panelViewModel: ClipboardPanelViewModel
    let panelController: PanelController
    let textBlockPanelViewModel: TextBlockPanelViewModel
    let textBlockPanelController: TextBlockPanelController
    let clipboardMonitor: ClipboardMonitor
    let hotkeyManager: HotkeyManager
    let toast: ToastPresenter

    @Published private(set) var hotkeyRegisterStatus: OSStatus = noErr
    @Published private(set) var textBlockHotkeyRegisterStatus: OSStatus = noErr

    init() {
        let schema = Schema([ClipboardEntry.self, TextBlockEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        let modelContainer = try! ModelContainer(for: schema, configurations: [config])

        let preferences = PreferencesStore()
        let ignoreAppStore = IgnoreAppStore()
        let clipboardStore = ClipboardStore(modelContainer: modelContainer, preferences: preferences)
        let textBlockStore = TextBlockStore(modelContainer: modelContainer)
        let pasteService = PasteService()
        let toast = ToastPresenter()

        let panelViewModel = ClipboardPanelViewModel(pageSize: 5)
        let panelController = PanelController(viewModel: panelViewModel) { entry, previousApp in
            Self.pasteClipboardEntry(entry, previousApp: previousApp, pasteService: pasteService, toast: toast)
        }

        let textBlockPanelViewModel = TextBlockPanelViewModel(pageSize: 5)
        let textBlockPanelController = TextBlockPanelController(viewModel: textBlockPanelViewModel) { entry, previousApp in
            Self.pasteTextBlockEntry(entry, previousApp: previousApp, pasteService: pasteService, toast: toast)
        }

        let clipboardMonitor = ClipboardMonitor(
            pasteboard: SystemPasteboardClient(),
            frontmostAppProvider: SystemFrontmostAppProvider(),
            logic: ClipboardMonitorLogic(ignoreAppStore: ignoreAppStore, clipboardStore: clipboardStore)
        )

        let hotkeyManager = HotkeyManager(onHotkeyAction: { action in
            switch AppHotkeyRoute(action: action) {
            case .clipboard:
                let items = (try? clipboardStore.fetchLatest(limit: 500)) ?? []
                panelViewModel.setEntries(Self.makePanelEntries(from: items))
                panelController.toggle()
            case .textBlock:
                let items = (try? textBlockStore.fetchAllBySortOrder()) ?? []
                textBlockPanelViewModel.setEntries(TextBlockPanelMapper.makeEntries(from: items))
                textBlockPanelController.toggle()
            }
        }
        )

        self.modelContainer = modelContainer
        self.preferences = preferences
        self.ignoreAppStore = ignoreAppStore
        self.clipboardStore = clipboardStore
        self.textBlockStore = textBlockStore
        self.pasteService = pasteService
        self.toast = toast
        self.panelViewModel = panelViewModel
        self.panelController = panelController
        self.textBlockPanelViewModel = textBlockPanelViewModel
        self.textBlockPanelController = textBlockPanelController
        self.clipboardMonitor = clipboardMonitor
        self.hotkeyManager = hotkeyManager
    }

    func start() {
        clipboardMonitor.start()
        hotkeyRegisterStatus = hotkeyManager.register(preferences.hotkey, for: .clipboardPanel)
        textBlockHotkeyRegisterStatus = hotkeyManager.register(preferences.textBlockHotkey, for: .textBlockPanel)
    }

    func togglePanel() {
        refreshPanelEntries()
        panelController.toggle()
    }

    func refreshPanelEntries() {
        let items = (try? clipboardStore.fetchLatest(limit: 500)) ?? []
        panelViewModel.setEntries(Self.makePanelEntries(from: items))
    }

    func toggleTextBlockPanel() {
        refreshTextBlockPanelEntries()
        textBlockPanelController.toggle()
    }

    func refreshTextBlockPanelEntries() {
        let items = (try? textBlockStore.fetchAllBySortOrder()) ?? []
        textBlockPanelViewModel.setEntries(TextBlockPanelMapper.makeEntries(from: items))
    }

    func applyHotkey(_ hotkey: Hotkey) {
        preferences.hotkey = hotkey
        hotkeyRegisterStatus = hotkeyManager.register(hotkey, for: .clipboardPanel)
    }

    func applyTextBlockHotkey(_ hotkey: Hotkey) {
        preferences.textBlockHotkey = hotkey
        textBlockHotkeyRegisterStatus = hotkeyManager.register(hotkey, for: .textBlockPanel)
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

extension AppState {
    static func pasteClipboardEntry(
        _ entry: ClipboardPanelEntry,
        previousApp: RunningApplicationActivating?,
        pasteService: PasteService,
        toast: ToastPresenter,
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()
    ) {
        if permission.isProcessTrusted(promptIfNeeded: false) {
            previousApp?.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let result = pasteService.paste(entry: makePasteEntry(from: entry))
                if result == .copiedOnly {
                    toast.show(message: "已复制到剪贴板（可手动 ⌘V）")
                }
            }
        } else {
            _ = pasteService.paste(entry: makePasteEntry(from: entry))
            toast.show(message: "未开启辅助功能，已复制到剪贴板（可手动 ⌘V）")
        }
    }

    static func pasteTextBlockEntry(
        _ entry: TextBlockPanelEntry,
        previousApp: RunningApplicationActivating?,
        pasteService: PasteService,
        toast: ToastPresenter,
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()
    ) {
        if permission.isProcessTrusted(promptIfNeeded: false) {
            previousApp?.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let result = pasteService.paste(text: entry.content)
                if result == .copiedOnly {
                    toast.show(message: "已复制到剪贴板（可手动 ⌘V）")
                }
            }
        } else {
            _ = pasteService.paste(text: entry.content)
            toast.show(message: "未开启辅助功能，已复制到剪贴板（可手动 ⌘V）")
        }
    }
}

private extension AppState {
    static func makePanelEntries(from items: [ClipboardEntry]) -> [ClipboardPanelEntry] {
        items.map { entry in
            switch ClipboardEntryKind(raw: entry.kindRaw) {
            case .text:
                ClipboardPanelEntry(kind: .text, previewText: entry.text, createdAt: entry.createdAt, rtfData: nil, imagePath: nil)
            case .rtf:
                ClipboardPanelEntry(kind: .rtf, previewText: entry.text, createdAt: entry.createdAt, rtfData: entry.rtfData, imagePath: nil)
            case .image:
                ClipboardPanelEntry(kind: .image, previewText: imagePreviewName(from: entry.imagePath), createdAt: entry.createdAt, rtfData: nil, imagePath: entry.imagePath)
            }
        }
    }

    static func imagePreviewName(from imagePath: String?) -> String {
        guard let imagePath, imagePath.isEmpty == false else { return "图片" }
        let name = URL(fileURLWithPath: imagePath).lastPathComponent
        return name.isEmpty ? "图片" : name
    }

    static func makePasteEntry(from entry: ClipboardPanelEntry) -> ClipboardEntry {
        let pasteEntry = ClipboardEntry(text: entry.previewText)
        pasteEntry.kindRaw = entry.kind.rawValue
        pasteEntry.rtfData = entry.rtfData
        pasteEntry.imagePath = entry.imagePath
        return pasteEntry
    }
}
