# Text Block Panel Implementation Plan

> **For codex:** REQUIRED SUB-SKILL: Use superpowers-executing-plans to implement this plan task-by-task.

**Goal:** 在现有 Quicker 架构中新增“文本块（纯文本模板）”能力：独立全局热键唤出独立面板，支持键盘快速选择并插入；在设置页提供统一的增删改排序与热键配置。

**Architecture:** 数据层新增 `TextBlockEntry` + `TextBlockStore`（SwiftData）并与 `ClipboardEntry` 共用 `ModelContainer`。交互层新增 `TextBlockPanelViewModel`、`TextBlockPanelView`、`TextBlockPanelController`，复用现有 `PasteService` 进行插入。入口层将 `HotkeyManager` 重构为多 action 路由（`clipboardPanel` / `textBlockPanel`），`AppState` 统一编排双热键与双面板，设置页新增 `TextBlock` Tab 做管理。

**Tech Stack:** SwiftUI、AppKit、SwiftData、Carbon HotKey API、XCTest

---

## 0. 输入与验收标准（先读这些）

**需求/设计来源：**
- `docs/plans/2026-02-06-text-block-design.md`

**实现硬验收：**
- 文本块与剪切板历史完全解耦：独立数据模型、独立面板、独立热键。
- 文本块条目仅纯文本；选择后立即插入并关闭面板。
- 设置页 `TextBlock` Tab 可完成：新增、编辑、删除、拖拽排序、上移/下移、热键录制与冲突提示。
- 文本块热键与剪切板热键可独立配置且互不覆盖；注册失败时保留旧热键。
- 面板和设置页核心操作可键盘完成，空状态/错误状态文案可见。
- 回归不破坏已有能力：剪切板监控、剪切板面板、已有热键、已有测试。

---

## 1. 执行约束（必须遵守）

1) 在独立 worktree 执行，避免污染当前分支。  
2) 严格 TDD：先写失败测试，再最小实现，再跑通过。  
3) 小步提交：每个 `spawn_agent` 一次 commit。  
4) 任何 Xcode 相关操作必须按用途使用 **xc-build / xc-testing / xc-meta MCP**（`xcode_list` / `xcode_test` / `xcode_build` / `xcode_clean`），不要直接调用 `xcodebuild`。  
5) 执行阶段建议显式使用以下技能：`@superpowers-executing-plans`、`@superpowers-test-driven-development`、`@superpowers-systematic-debugging`、`@superpowers-verification-before-completion`。

---

### spawn_agent 1: TextBlock 数据模型与存储（SwiftData）

**Files:**
- Create: `quicker/TextBlock/TextBlockEntry.swift`
- Create: `quicker/TextBlock/TextBlockStore.swift`
- Test: `quickerTests/TextBlockStoreTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/TextBlockStoreTests.swift`:
```swift
import SwiftData
import XCTest
@testable import quicker

@MainActor
final class TextBlockStoreTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema([TextBlockEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [config])
    }

    func testCreateFetchUpdateDelete() throws {
        let container = try makeInMemoryContainer()
        let store = TextBlockStore(modelContainer: container)

        let created = try store.create(title: "问候", content: "你好，世界")
        var all = try store.fetchAllBySortOrder()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.uuid, created.uuid)
        XCTAssertEqual(all.first?.sortOrder, 0)

        try store.update(id: created.uuid, title: "问候语", content: "你好，Quicker")
        all = try store.fetchAllBySortOrder()
        XCTAssertEqual(all.first?.title, "问候语")
        XCTAssertEqual(all.first?.content, "你好，Quicker")

        try store.delete(id: created.uuid)
        XCTAssertEqual(try store.fetchAllBySortOrder().count, 0)
    }

    func testMoveRewritesSortOrderContinuously() throws {
        let container = try makeInMemoryContainer()
        let store = TextBlockStore(modelContainer: container)
        _ = try store.create(title: "A", content: "A")
        _ = try store.create(title: "B", content: "B")
        _ = try store.create(title: "C", content: "C")
        _ = try store.create(title: "D", content: "D")

        try store.move(fromOffsets: IndexSet(integer: 0), toOffset: 3)

        let all = try store.fetchAllBySortOrder()
        XCTAssertEqual(all.map(\.title), ["B", "C", "A", "D"])
        XCTAssertEqual(all.map(\.sortOrder), [0, 1, 2, 3])
    }

    func testCreateRejectsEmptyContent() throws {
        let container = try makeInMemoryContainer()
        let store = TextBlockStore(modelContainer: container)

        XCTAssertThrowsError(try store.create(title: "X", content: "   ")) { error in
            XCTAssertEqual(error as? TextBlockStoreError, .emptyContent)
        }
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-testing MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/TextBlockStoreTests"]
}
```

Expected: FAIL（`Cannot find 'TextBlockEntry' in scope` / `Cannot find 'TextBlockStore' in scope`）

**Step 3: Write minimal implementation**

Create `quicker/TextBlock/TextBlockEntry.swift`:
```swift
import Foundation
import SwiftData

@Model
final class TextBlockEntry {
    @Attribute(.unique) var uuid: UUID
    var title: String
    var content: String
    var sortOrder: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        uuid: UUID = UUID(),
        title: String,
        content: String,
        sortOrder: Int,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.uuid = uuid
        self.title = title
        self.content = content
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
```

Create `quicker/TextBlock/TextBlockStore.swift`:
```swift
import Foundation
import SwiftData

enum TextBlockStoreError: Error, Equatable {
    case emptyContent
    case notFound
}

@MainActor
final class TextBlockStore {
    private let modelContainer: ModelContainer
    private var context: ModelContext { modelContainer.mainContext }

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func fetchAllBySortOrder() throws -> [TextBlockEntry] {
        let descriptor = FetchDescriptor<TextBlockEntry>(
            sortBy: [
                SortDescriptor(\.sortOrder, order: .forward),
                SortDescriptor(\.createdAt, order: .forward),
            ]
        )
        return try context.fetch(descriptor)
    }

    @discardableResult
    func create(title: String, content: String, now: Date = .now) throws -> TextBlockEntry {
        let normalizedContent = try normalizedContent(content)
        let normalizedTitle = normalizedTitle(title, content: normalizedContent)
        let nextOrder = try (fetchAllBySortOrder().last?.sortOrder ?? -1) + 1

        let entry = TextBlockEntry(
            title: normalizedTitle,
            content: normalizedContent,
            sortOrder: nextOrder,
            createdAt: now,
            updatedAt: now
        )
        context.insert(entry)
        try context.save()
        return entry
    }

    func update(id: UUID, title: String, content: String, now: Date = .now) throws {
        let entry = try find(id: id)
        let normalizedContent = try normalizedContent(content)
        entry.title = normalizedTitle(title, content: normalizedContent)
        entry.content = normalizedContent
        entry.updatedAt = now
        try context.save()
    }

    func delete(id: UUID) throws {
        let entry = try find(id: id)
        context.delete(entry)

        let all = try fetchAllBySortOrder()
        for (index, item) in all.enumerated() {
            item.sortOrder = index
        }
        try context.save()
    }

    func move(fromOffsets: IndexSet, toOffset: Int, now: Date = .now) throws {
        guard fromOffsets.isEmpty == false else { return }

        let ordered = try fetchAllBySortOrder()
        let sources = fromOffsets.sorted()

        var moving: [TextBlockEntry] = []
        var remaining: [TextBlockEntry] = []
        for (index, entry) in ordered.enumerated() {
            if fromOffsets.contains(index) {
                moving.append(entry)
            } else {
                remaining.append(entry)
            }
        }

        var destination = toOffset
        for source in sources where source < toOffset {
            destination -= 1
        }
        destination = min(max(0, destination), remaining.count)

        remaining.insert(contentsOf: moving, at: destination)
        for (index, entry) in remaining.enumerated() {
            entry.sortOrder = index
            entry.updatedAt = now
        }
        try context.save()
    }

    private func find(id: UUID) throws -> TextBlockEntry {
        let descriptor = FetchDescriptor<TextBlockEntry>(
            predicate: #Predicate { $0.uuid == id }
        )
        guard let entry = try context.fetch(descriptor).first else {
            throw TextBlockStoreError.notFound
        }
        return entry
    }

    private func normalizedContent(_ raw: String) throws -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { throw TextBlockStoreError.emptyContent }
        return value
    }

    private func normalizedTitle(_ raw: String, content: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty == false { return value }
        let firstLine = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "未命名文本块" : String(firstLine.prefix(24))
    }
}
```

**Step 4: Run test to verify it passes**

Re-run the same `xcode_test`.

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/TextBlock/TextBlockEntry.swift quicker/TextBlock/TextBlockStore.swift quickerTests/TextBlockStoreTests.swift
git commit -m "feat(textblock): 新增文本块模型与存储能力"
```

---

### spawn_agent 2: TextBlock 面板 ViewModel 与 Entry

**Files:**
- Create: `quicker/TextBlock/TextBlockPanelEntry.swift`
- Create: `quicker/TextBlock/TextBlockPanelViewModel.swift`
- Test: `quickerTests/TextBlockPanelViewModelTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/TextBlockPanelViewModelTests.swift`:
```swift
import XCTest
@testable import quicker

@MainActor
final class TextBlockPanelViewModelTests: XCTestCase {
    func testDefaultSelectionIsFirstItem() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make("A"), make("B")])
        XCTAssertEqual(vm.selectedEntry?.title, "A")
    }

    func testArrowDownAtLastItemFlipsPage() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: (0..<7).map { make("\($0)") })
        vm.selectIndexInPage(4)
        vm.moveSelectionDown()
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedEntry?.title, "5")
    }

    func testCmdNumberMapping() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make("A"), make("B")])
        XCTAssertEqual(vm.entryForCmdNumber(2)?.title, "B")
        XCTAssertNil(vm.entryForCmdNumber(3))
    }
}

private func make(_ title: String) -> TextBlockPanelEntry {
    TextBlockPanelEntry(id: UUID(), title: title, content: "content")
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-testing MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/TextBlockPanelViewModelTests"]
}
```

Expected: FAIL（`Cannot find 'TextBlockPanelViewModel' in scope`）

**Step 3: Write minimal implementation**

Create `quicker/TextBlock/TextBlockPanelEntry.swift`:
```swift
import Foundation

struct TextBlockPanelEntry: Equatable {
    let id: UUID
    let title: String
    let content: String
}
```

Create `quicker/TextBlock/TextBlockPanelViewModel.swift`:
```swift
import Foundation

@MainActor
final class TextBlockPanelViewModel: ObservableObject {
    let pageSize: Int

    @Published private(set) var entries: [TextBlockPanelEntry]
    @Published private(set) var pageIndex: Int = 0
    @Published private(set) var selectedIndexInPage: Int = 0

    init(pageSize: Int = 5, entries: [TextBlockPanelEntry] = []) {
        self.pageSize = pageSize
        self.entries = entries
    }

    var pageCount: Int { Pagination.pageCount(totalCount: entries.count, pageSize: pageSize) }

    var visibleRange: Range<Int> {
        Pagination.rangeForPage(pageIndex: pageIndex, totalCount: entries.count, pageSize: pageSize)
    }

    var visibleEntries: ArraySlice<TextBlockPanelEntry> {
        entries[visibleRange]
    }

    var selectedEntry: TextBlockPanelEntry? {
        let absolute = visibleRange.lowerBound + selectedIndexInPage
        guard absolute < entries.count else { return nil }
        return entries[absolute]
    }

    func setEntries(_ newEntries: [TextBlockPanelEntry]) {
        entries = newEntries
        pageIndex = 0
        selectedIndexInPage = 0
    }

    func moveSelectionUp() {
        guard entries.isEmpty == false else { return }
        if selectedIndexInPage > 0 {
            selectedIndexInPage -= 1
            return
        }
        guard pageIndex > 0 else { return }
        pageIndex -= 1
        selectedIndexInPage = max(0, visibleEntries.count - 1)
    }

    func moveSelectionDown() {
        guard entries.isEmpty == false else { return }
        let maxIndex = max(0, visibleEntries.count - 1)
        if selectedIndexInPage < maxIndex {
            selectedIndexInPage += 1
            return
        }
        let lastPageIndex = max(0, pageCount - 1)
        guard pageIndex < lastPageIndex else { return }
        pageIndex += 1
        selectedIndexInPage = 0
    }

    func previousPage() {
        pageIndex = max(0, pageIndex - 1)
        selectedIndexInPage = 0
    }

    func nextPage() {
        pageIndex = min(max(0, pageCount - 1), pageIndex + 1)
        selectedIndexInPage = 0
    }

    func selectIndexInPage(_ index: Int) {
        let maxIndex = max(0, visibleEntries.count - 1)
        selectedIndexInPage = min(max(0, index), maxIndex)
    }

    func entryForCmdNumber(_ number: Int) -> TextBlockPanelEntry? {
        guard
            let absolute = Pagination.absoluteIndexForCmdNumber(
                cmdNumber: number,
                pageIndex: pageIndex,
                totalCount: entries.count,
                pageSize: pageSize
            )
        else { return nil }
        return entries[absolute]
    }
}
```

**Step 4: Run test to verify it passes**

Re-run the same `xcode_test`.

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/TextBlock/TextBlockPanelEntry.swift quicker/TextBlock/TextBlockPanelViewModel.swift quickerTests/TextBlockPanelViewModelTests.swift
git commit -m "feat(textblock): 新增文本块面板视图模型"
```

---

### spawn_agent 3: `PreferencesStore` 扩展 `textBlockHotkey`

**Files:**
- Modify: `quicker/Hotkey/Hotkey.swift`
- Modify: `quicker/Settings/PreferencesKeys.swift`
- Modify: `quicker/Settings/PreferencesStore.swift`
- Modify: `quickerTests/PreferencesKeysTests.swift`
- Modify: `quickerTests/PreferencesStoreTests.swift`

**Step 1: Write the failing test**

Update `quickerTests/PreferencesKeysTests.swift`:
```swift
import XCTest
@testable import quicker

final class PreferencesKeysTests: XCTestCase {
    func testDefaultsAreStable() {
        XCTAssertEqual(PreferencesKeys.maxHistoryCount.defaultValue, 200)
        XCTAssertEqual(PreferencesKeys.dedupeAdjacentEnabled.defaultValue, true)
        XCTAssertEqual(PreferencesKeys.hotkey.defaultValue, .default)
        XCTAssertEqual(PreferencesKeys.textBlockHotkey.defaultValue, .textBlockDefault)
    }
}
```

Update `quickerTests/PreferencesStoreTests.swift`（追加新断言）:
```swift
func testDefaultValues() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
    let store = PreferencesStore(userDefaults: defaults)

    XCTAssertEqual(store.maxHistoryCount, PreferencesKeys.maxHistoryCount.defaultValue)
    XCTAssertEqual(store.dedupeAdjacentEnabled, PreferencesKeys.dedupeAdjacentEnabled.defaultValue)
    XCTAssertEqual(store.hotkey, PreferencesKeys.hotkey.defaultValue)
    XCTAssertEqual(store.textBlockHotkey, PreferencesKeys.textBlockHotkey.defaultValue)
}

func testPersistAndReadBack() throws {
    let defaults = try XCTUnwrap(UserDefaults(suiteName: "test.\(UUID().uuidString)"))
    let store = PreferencesStore(userDefaults: defaults)

    store.maxHistoryCount = 10
    store.dedupeAdjacentEnabled = false
    store.hotkey = Hotkey(keyCode: 1, modifiers: 0)
    store.textBlockHotkey = Hotkey(keyCode: 11, modifiers: UInt32(cmdKey | shiftKey))

    XCTAssertEqual(store.maxHistoryCount, 10)
    XCTAssertEqual(store.dedupeAdjacentEnabled, false)
    XCTAssertEqual(store.hotkey, Hotkey(keyCode: 1, modifiers: 0))
    XCTAssertEqual(store.textBlockHotkey, Hotkey(keyCode: 11, modifiers: UInt32(cmdKey | shiftKey)))
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-testing MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/PreferencesKeysTests", "quickerTests/PreferencesStoreTests"]
}
```

Expected: FAIL（`Type 'PreferencesKeys' has no member 'textBlockHotkey'`）

**Step 3: Write minimal implementation**

Modify `quicker/Hotkey/Hotkey.swift`:
```swift
import Carbon
import Foundation

struct Hotkey: Equatable, Codable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = Hotkey(
        keyCode: 9, // v
        modifiers: UInt32(cmdKey | shiftKey)
    )

    static let textBlockDefault = Hotkey(
        keyCode: 11, // b
        modifiers: UInt32(cmdKey | shiftKey)
    )
}

extension Hotkey {
    var displayString: String {
        let modifiersString = HotkeyDisplay.modifiersString(modifiers)
        let keyString = HotkeyDisplay.keyString(keyCode)
        return modifiersString + keyString
    }
}
```

Modify `quicker/Settings/PreferencesKeys.swift`:
```swift
import Foundation

enum PreferencesKeys {
    enum maxHistoryCount {
        static let key = "maxHistoryCount"
        static let defaultValue = 200
    }

    enum dedupeAdjacentEnabled {
        static let key = "dedupeAdjacentEnabled"
        static let defaultValue = true
    }

    enum hotkey {
        static let key = "hotkey"
        static let defaultValue = Hotkey.default
    }

    enum textBlockHotkey {
        static let key = "textBlockHotkey"
        static let defaultValue = Hotkey.textBlockDefault
    }
}
```

Modify `quicker/Settings/PreferencesStore.swift`（追加属性）:
```swift
var textBlockHotkey: Hotkey {
    get {
        guard
            let data = userDefaults.data(forKey: PreferencesKeys.textBlockHotkey.key),
            let value = try? JSONDecoder().decode(Hotkey.self, from: data)
        else {
            return PreferencesKeys.textBlockHotkey.defaultValue
        }
        return value
    }
    set {
        let data = try? JSONEncoder().encode(newValue)
        userDefaults.set(data, forKey: PreferencesKeys.textBlockHotkey.key)
    }
}
```

**Step 4: Run test to verify it passes**

Re-run the same `xcode_test`.

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Hotkey/Hotkey.swift quicker/Settings/PreferencesKeys.swift quicker/Settings/PreferencesStore.swift quickerTests/PreferencesKeysTests.swift quickerTests/PreferencesStoreTests.swift
git commit -m "feat(settings): 增加文本块热键偏好存储"
```

---

### spawn_agent 4: `HotkeyManager` 多 action 路由

**Files:**
- Create: `quicker/Hotkey/HotkeyAction.swift`
- Create: `quicker/Hotkey/HotkeyRouteCodec.swift`
- Modify: `quicker/Hotkey/HotkeyManager.swift`
- Test: `quickerTests/HotkeyRouteCodecTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/HotkeyRouteCodecTests.swift`:
```swift
import Carbon
import XCTest
@testable import quicker

final class HotkeyRouteCodecTests: XCTestCase {
    func testEncodeDecodeRoundTrip() {
        for action in HotkeyAction.allCases {
            let id = HotkeyRouteCodec.makeID(for: action)
            XCTAssertEqual(id.signature, HotkeyRouteCodec.signature)
            XCTAssertEqual(HotkeyRouteCodec.decode(id), action)
        }
    }

    func testDecodeRejectsUnknownSignature() {
        var id = EventHotKeyID(signature: OSType(0x44454144), id: HotkeyAction.clipboardPanel.rawValue)
        XCTAssertNil(HotkeyRouteCodec.decode(id))
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-testing MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/HotkeyRouteCodecTests"]
}
```

Expected: FAIL（`Cannot find 'HotkeyRouteCodec' in scope`）

**Step 3: Write minimal implementation**

Create `quicker/Hotkey/HotkeyAction.swift`:
```swift
import Foundation

enum HotkeyAction: UInt32, CaseIterable {
    case clipboardPanel = 1
    case textBlockPanel = 2
}
```

Create `quicker/Hotkey/HotkeyRouteCodec.swift`:
```swift
import Carbon
import Foundation

enum HotkeyRouteCodec {
    static let signature = OSType(0x514B484B) // "QKHK"

    static func makeID(for action: HotkeyAction) -> EventHotKeyID {
        EventHotKeyID(signature: signature, id: action.rawValue)
    }

    static func decode(_ id: EventHotKeyID) -> HotkeyAction? {
        guard id.signature == signature else { return nil }
        return HotkeyAction(rawValue: id.id)
    }
}
```

Modify `quicker/Hotkey/HotkeyManager.swift`:
```swift
import Carbon
import Foundation

final class HotkeyManager {
    private var hotKeyRefs: [HotkeyAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private let onHotkeyAction: (HotkeyAction) -> Void

    convenience init(onHotkey: @escaping () -> Void) {
        self.init(onHotkeyAction: { action in
            guard action == .clipboardPanel else { return }
            onHotkey()
        })
    }

    init(onHotkeyAction: @escaping (HotkeyAction) -> Void) {
        self.onHotkeyAction = onHotkeyAction
    }

    @discardableResult
    func register(_ hotkey: Hotkey) -> OSStatus {
        register(hotkey, for: .clipboardPanel)
    }

    @discardableResult
    func register(_ hotkey: Hotkey, for action: HotkeyAction) -> OSStatus {
        installEventHandlerIfNeeded()
        unregister(action: action)

        var hotKeyRef: EventHotKeyRef?
        var id = HotkeyRouteCodec.makeID(for: action)
        let status = RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs[action] = hotKeyRef
        }
        return status
    }

    func unregister(action: HotkeyAction) {
        if let ref = hotKeyRefs[action] {
            UnregisterEventHotKey(ref)
            hotKeyRefs[action] = nil
        }
    }

    func unregisterAll() {
        for action in HotkeyAction.allCases {
            unregister(action: action)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }

    deinit {
        unregisterAll()
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                manager.handleHotkey(event)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    private func handleHotkey(_ event: EventRef?) {
        guard let event else { return }
        var id = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &id
        )
        guard status == noErr, let action = HotkeyRouteCodec.decode(id) else { return }
        onHotkeyAction(action)
    }
}
```

**Step 4: Run test to verify it passes**

Re-run the same `xcode_test`.

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/Hotkey/HotkeyAction.swift quicker/Hotkey/HotkeyRouteCodec.swift quicker/Hotkey/HotkeyManager.swift quickerTests/HotkeyRouteCodecTests.swift
git commit -m "refactor(hotkey): 重构热键管理为多动作路由"
```

---

### spawn_agent 5: TextBlock 面板 View + Controller + Mapper

**Files:**
- Create: `quicker/TextBlock/TextBlockPanelMapper.swift`
- Create: `quicker/TextBlock/TextBlockPanelView.swift`
- Create: `quicker/TextBlock/TextBlockPanelController.swift`
- Test: `quickerTests/TextBlockPanelMapperTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/TextBlockPanelMapperTests.swift`:
```swift
import XCTest
@testable import quicker

@MainActor
final class TextBlockPanelMapperTests: XCTestCase {
    func testMapperFallsBackToFirstLineWhenTitleEmpty() {
        let entry = TextBlockEntry(title: "   ", content: "第一行\n第二行", sortOrder: 0)
        let mapped = TextBlockPanelMapper.makeEntries(from: [entry])

        XCTAssertEqual(mapped.count, 1)
        XCTAssertEqual(mapped[0].title, "第一行")
        XCTAssertEqual(mapped[0].content, "第一行\n第二行")
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-testing MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/TextBlockPanelMapperTests"]
}
```

Expected: FAIL（`Cannot find 'TextBlockPanelMapper' in scope`）

**Step 3: Write minimal implementation**

Create `quicker/TextBlock/TextBlockPanelMapper.swift`:
```swift
import Foundation

enum TextBlockPanelMapper {
    static func makeEntries(from items: [TextBlockEntry]) -> [TextBlockPanelEntry] {
        items.map { item in
            let title = normalizedTitle(item.title, content: item.content)
            return TextBlockPanelEntry(id: item.uuid, title: title, content: item.content)
        }
    }

    private static func normalizedTitle(_ raw: String, content: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty == false { return t }
        let firstLine = content.split(separator: "\n", maxSplits: 1).first.map(String.init) ?? ""
        return firstLine.isEmpty ? "未命名文本块" : String(firstLine.prefix(24))
    }
}
```

Create `quicker/TextBlock/TextBlockPanelView.swift`:
```swift
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
        if event.keyCode == 53 { onClose(); return } // Esc

        if event.modifierFlags.contains(.command), event.charactersIgnoringModifiers == "," {
            onClose()
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            return
        }

        if event.keyCode == 36 { // Enter
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
```

Create `quicker/TextBlock/TextBlockPanelController.swift`:
```swift
import AppKit
import SwiftUI

@MainActor
final class TextBlockPanelController: NSObject, NSWindowDelegate {
    private var panel: CenteredPanel?
    private let viewModel: TextBlockPanelViewModel
    private let onInsert: (TextBlockPanelEntry, NSRunningApplication?) -> Void
    private var previousFrontmostApp: NSRunningApplication?

    init(
        viewModel: TextBlockPanelViewModel,
        onInsert: @escaping (TextBlockPanelEntry, NSRunningApplication?) -> Void
    ) {
        self.viewModel = viewModel
        self.onInsert = onInsert
    }

    func toggle() {
        if panel?.isVisible == true { close() } else { show() }
    }

    func show() {
        if panel == nil { panel = makePanel() }
        guard let panel else { return }
        previousFrontmostApp = NSWorkspace.shared.frontmostApplication
        center(panel)
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel?.orderOut(nil)
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func makePanel() -> CenteredPanel {
        let size = QuickerTheme.ClipboardPanel.size
        let content = TextBlockPanelView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.close() },
            onInsert: { [weak self] entry in
                guard let self else { return }
                self.close()
                self.onInsert(entry, self.previousFrontmostApp)
            }
        )
        let hosting = NSHostingController(rootView: content)
        let panel = CenteredPanel(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.delegate = self
        panel.contentViewController = hosting
        return panel
    }

    private func preferredScreen() -> NSScreen? {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
    }

    private func center(_ panel: NSWindow) {
        guard let screen = preferredScreen() else { return }
        let frame = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(CGPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2))
    }
}
```

**Step 4: Run test to verify it passes**

1) 先跑 mapper 单测：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/TextBlockPanelMapperTests"]
}
```

2) 再做一次编译检查（确保新 View/Controller 可编译）：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac"
}
```

Expected: PASS / BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add quicker/TextBlock/TextBlockPanelMapper.swift quicker/TextBlock/TextBlockPanelView.swift quicker/TextBlock/TextBlockPanelController.swift quickerTests/TextBlockPanelMapperTests.swift
git commit -m "feat(textblock): 新增文本块面板视图与控制器"
```

---

### spawn_agent 6: `AppState` 编排接入（双热键 + 双面板）

**Files:**
- Create: `quicker/App/AppHotkeyRoute.swift`
- Test: `quickerTests/AppHotkeyRouteTests.swift`
- Modify: `quicker/App/AppState.swift`
- Modify: `quicker/quickerApp.swift`

**Step 1: Write the failing test**

Create `quickerTests/AppHotkeyRouteTests.swift`:
```swift
import XCTest
@testable import quicker

final class AppHotkeyRouteTests: XCTestCase {
    func testMapsHotkeyActionToPanelTarget() {
        XCTAssertEqual(AppHotkeyRoute(action: .clipboardPanel), .clipboard)
        XCTAssertEqual(AppHotkeyRoute(action: .textBlockPanel), .textBlock)
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-testing MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/AppHotkeyRouteTests"]
}
```

Expected: FAIL（`Cannot find 'AppHotkeyRoute' in scope`）

**Step 3: Write minimal implementation**

Create `quicker/App/AppHotkeyRoute.swift`:
```swift
import Foundation

enum AppHotkeyRoute: Equatable {
    case clipboard
    case textBlock

    init(action: HotkeyAction) {
        switch action {
        case .clipboardPanel:
            self = .clipboard
        case .textBlockPanel:
            self = .textBlock
        }
    }
}
```

Modify `quicker/App/AppState.swift`（关键改动）:
```swift
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
        })

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

    func toggleTextBlockPanel() {
        refreshTextBlockPanelEntries()
        textBlockPanelController.toggle()
    }

    func refreshTextBlockPanelEntries() {
        let items = (try? textBlockStore.fetchAllBySortOrder()) ?? []
        textBlockPanelViewModel.setEntries(TextBlockPanelMapper.makeEntries(from: items))
    }

    func applyTextBlockHotkey(_ hotkey: Hotkey) {
        preferences.textBlockHotkey = hotkey
        textBlockHotkeyRegisterStatus = hotkeyManager.register(hotkey, for: .textBlockPanel)
    }

    private static func pasteClipboardEntry(
        _ entry: ClipboardPanelEntry,
        previousApp: NSRunningApplication?,
        pasteService: PasteService,
        toast: ToastPresenter
    ) {
        if SystemAccessibilityPermission().isProcessTrusted(promptIfNeeded: false) {
            previousApp?.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let result = pasteService.paste(entry: makePasteEntry(from: entry))
                if result == .copiedOnly { toast.show(message: "已复制到剪贴板（可手动 ⌘V）") }
            }
        } else {
            _ = pasteService.paste(entry: makePasteEntry(from: entry))
            toast.show(message: "未开启辅助功能，已复制到剪贴板（可手动 ⌘V）")
        }
    }

    private static func pasteTextBlockEntry(
        _ entry: TextBlockPanelEntry,
        previousApp: NSRunningApplication?,
        pasteService: PasteService,
        toast: ToastPresenter
    ) {
        if SystemAccessibilityPermission().isProcessTrusted(promptIfNeeded: false) {
            previousApp?.activate(options: [])
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let result = pasteService.paste(text: entry.content)
                if result == .copiedOnly { toast.show(message: "已复制到剪贴板（可手动 ⌘V）") }
            }
        } else {
            _ = pasteService.paste(text: entry.content)
            toast.show(message: "未开启辅助功能，已复制到剪贴板（可手动 ⌘V）")
        }
    }
}
```

Modify `quicker/quickerApp.swift`（菜单增加入口）:
```swift
MenuBarExtra {
    Button("Open Clipboard Panel") {
        appState.togglePanel()
    }
    Button("Open Text Block Panel") {
        appState.toggleTextBlockPanel()
    }
    SettingsLink {
        Text("Settings…")
    }
    Divider()
    Button("Clear History") {
        appState.confirmAndClearHistory()
    }
    Divider()
    Button("Quit") { NSApp.terminate(nil) }
} label: {
    Image(systemName: "bolt.fill")
        .symbolRenderingMode(.hierarchical)
        .accessibilityLabel("Quicker")
}
```

**Step 4: Run test to verify it passes**

1) 跑新增路由测试：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/AppHotkeyRouteTests"]
}
```

2) 跑一组关键回归：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": [
    "quickerTests/ClipboardStoreTests",
    "quickerTests/ClipboardPanelViewModelTests",
    "quickerTests/PasteServiceLogicTests"
  ]
}
```

Expected: PASS

**Step 5: Commit**

```bash
git add quicker/App/AppHotkeyRoute.swift quicker/App/AppState.swift quicker/quickerApp.swift quickerTests/AppHotkeyRouteTests.swift
git commit -m "feat(app): 接入文本块面板与双热键编排"
```

---

### spawn_agent 7: 设置页 `TextBlock` Tab + 热键校验

**Files:**
- Create: `quicker/Hotkey/HotkeyValidation.swift`
- Create: `quicker/Settings/TextBlockSettingsView.swift`
- Modify: `quicker/Settings/SettingsView.swift`
- Test: `quickerTests/HotkeyValidationTests.swift`

**Step 1: Write the failing test**

Create `quickerTests/HotkeyValidationTests.swift`:
```swift
import Carbon
import XCTest
@testable import quicker

final class HotkeyValidationTests: XCTestCase {
    func testRejectsWhenMissingCommand() {
        let candidate = Hotkey(keyCode: 11, modifiers: UInt32(shiftKey))
        XCTAssertEqual(
            HotkeyValidation.validateTextBlock(candidate, clipboardHotkey: .default),
            .missingCommand
        )
    }

    func testRejectsWhenSameAsClipboardHotkey() {
        XCTAssertEqual(
            HotkeyValidation.validateTextBlock(.default, clipboardHotkey: .default),
            .conflictsWithClipboard
        )
    }

    func testAcceptsCmdShiftB() {
        XCTAssertEqual(
            HotkeyValidation.validateTextBlock(.textBlockDefault, clipboardHotkey: .default),
            nil
        )
    }
}
```

**Step 2: Run test to verify it fails**

Invoke（xc-testing MCP / `xcode_test`）:
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/HotkeyValidationTests"]
}
```

Expected: FAIL（`Cannot find 'HotkeyValidation' in scope`）

**Step 3: Write minimal implementation**

Create `quicker/Hotkey/HotkeyValidation.swift`:
```swift
import Carbon
import Foundation

enum HotkeyValidationError: Equatable {
    case missingCommand
    case conflictsWithClipboard
}

enum HotkeyValidation {
    static func validateTextBlock(_ hotkey: Hotkey, clipboardHotkey: Hotkey) -> HotkeyValidationError? {
        let hasCommand = (hotkey.modifiers & UInt32(cmdKey)) != 0
        guard hasCommand else { return .missingCommand }
        guard hotkey != clipboardHotkey else { return .conflictsWithClipboard }
        return nil
    }
}
```

Create `quicker/Settings/TextBlockSettingsView.swift`:
```swift
import Carbon
import SwiftUI

struct TextBlockSettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var entries: [TextBlockEntry] = []
    @State private var selectedID: UUID?
    @State private var editTitle: String = ""
    @State private var editContent: String = ""

    @State private var isRecordingHotkey = false
    @State private var textBlockHotkey: Hotkey = .textBlockDefault
    @State private var hotkeyError: String?

    var body: some View {
        Form {
            Section("文本块面板快捷键") {
                LabeledContent("快捷键") {
                    HStack(spacing: 10) {
                        Text(textBlockHotkey.displayString).monospacedDigit()
                        Button("修改…") { isRecordingHotkey = true }
                    }
                }

                if let hotkeyError {
                    Text(hotkeyError)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if appState.textBlockHotkeyRegisterStatus != noErr {
                    Text("快捷键可能冲突，请更换组合。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("建议包含 ⌘，避免与应用常用快捷键冲突。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Section("文本块") {
                HStack(alignment: .top, spacing: 12) {
                    List(selection: $selectedID) {
                        ForEach(entries, id: \.uuid) { entry in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.title).lineLimit(1)
                                Text(entry.content).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .tag(entry.uuid)
                        }
                        .onMove(perform: moveRows)
                    }
                    .frame(minWidth: 240, minHeight: 260)

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("标题", text: $editTitle)
                            .onSubmit(saveSelection)
                        TextEditor(text: $editContent)
                            .frame(minHeight: 180)
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 1))
                        HStack {
                            Button("新建", action: createEntry)
                            Button("删除", role: .destructive, action: deleteSelection).disabled(selectedID == nil)
                            Button("上移", action: moveUp).disabled(selectedID == nil)
                            Button("下移", action: moveDown).disabled(selectedID == nil)
                            Spacer()
                            Button("保存", action: saveSelection).disabled(selectedID == nil)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: load)
        .onDisappear(perform: saveSelection)
        .onChange(of: selectedID) { _ in loadSelectionDraft() }
        .sheet(isPresented: $isRecordingHotkey) {
            TextBlockHotkeyRecorderSheet(
                onCancel: { isRecordingHotkey = false },
                onCapture: handleHotkeyCapture
            )
        }
    }

    private func load() {
        textBlockHotkey = appState.preferences.textBlockHotkey
        entries = (try? appState.textBlockStore.fetchAllBySortOrder()) ?? []
        if selectedID == nil { selectedID = entries.first?.uuid }
        loadSelectionDraft()
    }

    private func loadSelectionDraft() {
        guard let selectedID, let selected = entries.first(where: { $0.uuid == selectedID }) else {
            editTitle = ""
            editContent = ""
            return
        }
        editTitle = selected.title
        editContent = selected.content
    }

    private func createEntry() {
        if let created = try? appState.textBlockStore.create(title: "新文本块", content: "请编辑内容") {
            reload(keep: created.uuid)
            appState.refreshTextBlockPanelEntries()
        }
    }

    private func saveSelection() {
        guard let selectedID else { return }
        guard let _ = try? appState.textBlockStore.update(id: selectedID, title: editTitle, content: editContent) else { return }
        reload(keep: selectedID)
        appState.refreshTextBlockPanelEntries()
    }

    private func deleteSelection() {
        guard let selectedID else { return }
        try? appState.textBlockStore.delete(id: selectedID)
        reload(keep: entries.first(where: { $0.uuid != selectedID })?.uuid)
        appState.refreshTextBlockPanelEntries()
    }

    private func moveRows(from offsets: IndexSet, to destination: Int) {
        try? appState.textBlockStore.move(fromOffsets: offsets, toOffset: destination)
        reload(keep: selectedID)
        appState.refreshTextBlockPanelEntries()
    }

    private func moveUp() {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }), index > 0 else { return }
        moveRows(from: IndexSet(integer: index), to: index - 1)
    }

    private func moveDown() {
        guard let selectedID, let index = entries.firstIndex(where: { $0.uuid == selectedID }), index < entries.count - 1 else { return }
        moveRows(from: IndexSet(integer: index), to: index + 2)
    }

    private func reload(keep id: UUID?) {
        entries = (try? appState.textBlockStore.fetchAllBySortOrder()) ?? []
        selectedID = id ?? entries.first?.uuid
        loadSelectionDraft()
    }

    private func handleHotkeyCapture(_ event: NSEvent) {
        if event.keyCode == 53 { // Esc
            isRecordingHotkey = false
            return
        }

        let modifiers = carbonModifiers(from: event.modifierFlags)
        let candidate = Hotkey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
        if let error = HotkeyValidation.validateTextBlock(candidate, clipboardHotkey: appState.preferences.hotkey) {
            switch error {
            case .missingCommand:
                hotkeyError = "文本块快捷键必须包含 ⌘。"
            case .conflictsWithClipboard:
                hotkeyError = "不能与剪切板面板快捷键相同。"
            }
            return
        }

        hotkeyError = nil
        textBlockHotkey = candidate
        appState.applyTextBlockHotkey(candidate)
        isRecordingHotkey = false
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var result: UInt32 = 0
        if flags.contains(.command) { result |= UInt32(cmdKey) }
        if flags.contains(.shift) { result |= UInt32(shiftKey) }
        if flags.contains(.option) { result |= UInt32(optionKey) }
        if flags.contains(.control) { result |= UInt32(controlKey) }
        return result
    }
}

private struct TextBlockHotkeyRecorderSheet: View {
    var onCancel: () -> Void
    var onCapture: (NSEvent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "keyboard")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text("按下新的文本块快捷键")
                        .font(.headline)
                    Text("按 Esc 取消；必须包含 ⌘")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.quaternary.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.quaternary, lineWidth: 1)
                )
                .frame(height: 60)
                .overlay(
                    Text("正在监听键盘输入…")
                        .foregroundStyle(.secondary)
                )

            HStack {
                Spacer()
                Button("取消") { onCancel() }
                    .keyboardShortcut(.cancelAction)
            }

            HotkeyRecorderView { event in
                onCapture(event)
            }
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .padding(16)
        .frame(width: 440, height: 210)
    }
}
```

Modify `quicker/Settings/SettingsView.swift`:
```swift
import SwiftUI

struct SettingsView: View {
    private enum Tab: String, Hashable {
        case general
        case clipboard
        case textBlock
        case about
    }

    @State private var tab: Tab = .general

    var body: some View {
        TabView(selection: $tab) {
            SettingsPage {
                GeneralSettingsView()
            }
            .tabItem { Label("通用", systemImage: "gearshape") }
            .tag(Tab.general)

            SettingsPage {
                ClipboardSettingsView()
            }
            .tabItem { Label("剪切板", systemImage: "doc.on.clipboard") }
            .tag(Tab.clipboard)

            SettingsPage {
                TextBlockSettingsView()
            }
            .tabItem { Label("文本块", systemImage: "text.bubble") }
            .tag(Tab.textBlock)

            SettingsPage {
                AboutView()
            }
            .tabItem { Label("关于", systemImage: "info.circle") }
            .tag(Tab.about)
        }
        .frame(width: 720, height: 520)
    }
}
```

**Step 4: Run test to verify it passes**

1) 跑新增单测：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": ["quickerTests/HotkeyValidationTests"]
}
```

2) 编译检查：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac"
}
```

Expected: PASS / BUILD SUCCEEDED

**Step 5: Commit**

```bash
git add quicker/Hotkey/HotkeyValidation.swift quicker/Settings/TextBlockSettingsView.swift quicker/Settings/SettingsView.swift quickerTests/HotkeyValidationTests.swift
git commit -m "feat(settings): 新增文本块设置页与热键校验"
```

---

## 2. 最终回归与验收（收口步骤）

1) 运行文本块相关测试集：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": [
    "quickerTests/TextBlockStoreTests",
    "quickerTests/TextBlockPanelViewModelTests",
    "quickerTests/TextBlockPanelMapperTests",
    "quickerTests/HotkeyRouteCodecTests",
    "quickerTests/HotkeyValidationTests",
    "quickerTests/AppHotkeyRouteTests"
  ]
}
```

2) 跑关键存量回归：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac",
  "only_testing": [
    "quickerTests/ClipboardStoreTests",
    "quickerTests/ClipboardPanelViewModelTests",
    "quickerTests/PasteServiceLogicTests",
    "quickerTests/PreferencesStoreTests"
  ]
}
```

3) 全量测试：
```json
{
  "project_path": "quicker.xcodeproj",
  "scheme": "quicker",
  "destination": "platform=macOS,name=Any Mac"
}
```

4) 手测清单（必须逐项勾选）：
- 用剪切板热键唤出剪切板面板，功能正常。
- 用文本块热键唤出文本块面板，`Esc`/`Enter`/`↑↓`/`←→`/`⌘1..5` 正常。
- 在设置页新增、编辑、删除、拖拽排序、上移/下移后，文本块面板实时反映最新顺序与内容。
- 把文本块热键改成冲突值时有提示且不会破坏旧热键。
- 未开启辅助功能权限时，文本块插入行为正确降级为“仅复制并提示”。

5) 收口提交（仅当前 7 个子任务都完成且测试通过后）：
```bash
git add .
git commit -m "test(textblock): 完成文本块功能回归验证"
```
