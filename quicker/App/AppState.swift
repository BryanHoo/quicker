import AppKit
import Combine
import Carbon
import Foundation
import OSLog
import SwiftData

@MainActor
final class AppState: ObservableObject {
    private let logger = Logger(subsystem: "quicker", category: "AppState")

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
        let (modelContainer, isUsingInMemoryStore) = Self.createModelContainer(schema: schema)

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

        let appStateLogger = Logger(subsystem: "quicker", category: "AppState")
        let hotkeyManager = HotkeyManager(onHotkeyAction: { action in
            switch AppHotkeyRoute(action: action) {
            case .clipboard:
                if isUsingInMemoryStore {
                    toast.show(message: "当前处于内存模式（无法读取/写入历史）。如果这是开机自启后发生的，请退出并重新打开。", duration: 2.4)
                }

                let items: [ClipboardEntry]
                do {
                    items = try clipboardStore.fetchLatest(limit: 500)
                } catch {
                    appStateLogger.error("clipboardStore.fetchLatest(limit:) failed: \(String(describing: error), privacy: .public)")
                    toast.show(message: "读取剪切板历史失败，请稍后重试或重启。", duration: 2.4)
                    items = []
                }
                panelViewModel.setEntries(Self.makePanelEntries(from: items))
                panelController.toggle()
            case .textBlock:
                if isUsingInMemoryStore {
                    toast.show(message: "当前处于内存模式（无法读取/写入历史）。如果这是开机自启后发生的，请退出并重新打开。", duration: 2.4)
                }

                let items: [TextBlockEntry]
                do {
                    items = try textBlockStore.fetchAllBySortOrder()
                } catch {
                    appStateLogger.error("textBlockStore.fetchAllBySortOrder() failed: \(String(describing: error), privacy: .public)")
                    toast.show(message: "读取文本块失败，请稍后重试或重启。", duration: 2.4)
                    items = []
                }
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

    private static func createModelContainer(schema: Schema) -> (ModelContainer, Bool) {
        let logger = Logger(subsystem: "quicker", category: "SwiftData")

        do {
            let appSupport = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            if let bundleId = Bundle.main.bundleIdentifier {
                let dir = appSupport.appendingPathComponent(bundleId, isDirectory: true)
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
        } catch {
            logger.error("Failed to prepare Application Support directory: \(String(describing: error), privacy: .public)")
        }

        let retryDelays: [TimeInterval] = [0.12, 0.3, 0.8]
        var lastError: Error?
        for attemptIndex in 0...retryDelays.count {
            let attempt = attemptIndex + 1
            let retryCount = attemptIndex
            do {
                let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                let container = try ModelContainer(for: schema, configurations: [config])
                if retryCount > 0 {
                    logger.info("Created persistent ModelContainer after retryCount=\(retryCount, privacy: .public)")
                }
                return (container, false)
            } catch {
                lastError = error
                let nsError = error as NSError
                logger.error("Failed to create persistent ModelContainer attempt=\(attempt, privacy: .public) domain=\(nsError.domain, privacy: .public) code=\(nsError.code, privacy: .public) error=\(String(describing: error), privacy: .public)")
                if attemptIndex < retryDelays.count {
                    Thread.sleep(forTimeInterval: retryDelays[attemptIndex])
                }
            }
        }

        do {
            let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            let container = try ModelContainer(for: schema, configurations: [config])
            logger.error("Falling back to in-memory ModelContainer due to persistent error: \(String(describing: lastError ?? NSError(domain: "unknown", code: -1, userInfo: nil)), privacy: .public)")
            return (container, true)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    func start() {
        logger.info("start() isUsingInMemoryStore=\(self.isUsingInMemoryStore, privacy: .public)")
        clipboardMonitor.start()
        hotkeyRegisterStatus = hotkeyManager.register(preferences.hotkey, for: .clipboardPanel)
        textBlockHotkeyRegisterStatus = hotkeyManager.register(preferences.textBlockHotkey, for: .textBlockPanel)
        if isUsingInMemoryStore {
            toast.show(message: "无法创建持久化存储，已切换为内存模式（重启后不会保留历史）", duration: 2.4)
        }
    }

    func togglePanel() {
        if isUsingInMemoryStore {
            toast.show(message: "当前处于内存模式（无法读取/写入历史）。如果这是开机自启后发生的，请退出并重新打开。", duration: 2.4)
        }
        refreshPanelEntries()
        panelController.toggle()
    }

    func refreshPanelEntries() {
        let items: [ClipboardEntry]
        do {
            items = try clipboardStore.fetchLatest(limit: 500)
        } catch {
            logger.error("clipboardStore.fetchLatest(limit:) failed: \(String(describing: error), privacy: .public)")
            toast.show(message: "读取剪切板历史失败，请稍后重试或重启。", duration: 2.4)
            items = []
        }
        panelViewModel.setEntries(Self.makePanelEntries(from: items))
    }

    func toggleTextBlockPanel() {
        if isUsingInMemoryStore {
            toast.show(message: "当前处于内存模式（无法读取/写入历史）。如果这是开机自启后发生的，请退出并重新打开。", duration: 2.4)
        }
        refreshTextBlockPanelEntries()
        textBlockPanelController.toggle()
    }

    func refreshTextBlockPanelEntries() {
        let items: [TextBlockEntry]
        do {
            items = try textBlockStore.fetchAllBySortOrder()
        } catch {
            logger.error("textBlockStore.fetchAllBySortOrder() failed: \(String(describing: error), privacy: .public)")
            toast.show(message: "读取文本块失败，请稍后重试或重启。", duration: 2.4)
            items = []
        }
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
