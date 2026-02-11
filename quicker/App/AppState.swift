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
    private let isUsingInMemoryStore: Bool

    @Published private(set) var hotkeyRegisterStatus: OSStatus = noErr
    @Published private(set) var textBlockHotkeyRegisterStatus: OSStatus = noErr

    init() {
        let schema = Schema([ClipboardEntry.self, TextBlockEntry.self])
        let modelContainer: ModelContainer
        let isUsingInMemoryStore: Bool
        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            modelContainer = try ModelContainer(for: schema, configurations: [config])
            isUsingInMemoryStore = false
        } catch {
            let persistentError = error
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                modelContainer = try ModelContainer(for: schema, configurations: [config])
                isUsingInMemoryStore = true
                NSLog("Failed to create persistent ModelContainer, falling back to in-memory store: \(persistentError)")
            } catch {
                fatalError("Failed to create ModelContainer: \(error)")
            }
        }

        let preferences = PreferencesStore()
        let ignoreAppStore = IgnoreAppStore()
        let clipboardStore = ClipboardStore(modelContainer: modelContainer, preferences: preferences)
        let textBlockStore = TextBlockStore(modelContainer: modelContainer)
        let pasteService = PasteService()
        let toast = ToastPresenter()

        let panelViewModel = ClipboardPanelViewModel(pageSize: 5)
        let panelController = PanelController(viewModel: panelViewModel) { entry, previousApp in
            Self.pasteClipboardEntry(entry, previousApp: previousApp, pasteService: pasteService)
        }

        let textBlockPanelViewModel = TextBlockPanelViewModel(pageSize: 5)
        let textBlockPanelController = TextBlockPanelController(viewModel: textBlockPanelViewModel) { entry, previousApp in
            Self.pasteTextBlockEntry(entry, previousApp: previousApp, pasteService: pasteService)
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
        self.isUsingInMemoryStore = isUsingInMemoryStore
    }

    func start() {
        clipboardMonitor.start()
        hotkeyRegisterStatus = hotkeyManager.register(preferences.hotkey, for: .clipboardPanel)
        textBlockHotkeyRegisterStatus = hotkeyManager.register(preferences.textBlockHotkey, for: .textBlockPanel)
        if isUsingInMemoryStore {
            toast.show(message: "无法创建持久化存储，已切换为内存模式（重启后不会保留历史）", duration: 2.4)
        }
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
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()
    ) {
        if permission.isProcessTrusted(promptIfNeeded: true) {
            previousApp?.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                _ = pasteService.paste(entry: makePasteEntry(from: entry))
            }
        } else {
            _ = pasteService.paste(entry: makePasteEntry(from: entry))
        }
    }

    static func pasteTextBlockEntry(
        _ entry: TextBlockPanelEntry,
        previousApp: RunningApplicationActivating?,
        pasteService: PasteService,
        permission: AccessibilityPermissionChecking = SystemAccessibilityPermission()
    ) {
        if permission.isProcessTrusted(promptIfNeeded: true) {
            previousApp?.activate(options: [.activateIgnoringOtherApps])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                _ = pasteService.paste(text: entry.content)
            }
        } else {
            _ = pasteService.paste(text: entry.content)
        }
    }
}

private extension AppState {
    static func makePanelEntries(from items: [ClipboardEntry]) -> [ClipboardPanelEntry] {
        items.map { entry in
            switch ClipboardEntryKind(raw: entry.kindRaw) {
            case .text:
                ClipboardPanelEntry(kind: .text, previewText: entry.text, createdAt: entry.createdAt, rtfData: nil, imagePath: nil, contentHash: entry.contentHash)
            case .rtf:
                ClipboardPanelEntry(kind: .rtf, previewText: entry.text, createdAt: entry.createdAt, rtfData: entry.rtfData, imagePath: nil, contentHash: entry.contentHash)
            case .image:
                ClipboardPanelEntry(kind: .image, previewText: imagePreviewName(from: entry.imagePath), createdAt: entry.createdAt, rtfData: nil, imagePath: entry.imagePath, contentHash: entry.contentHash)
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
