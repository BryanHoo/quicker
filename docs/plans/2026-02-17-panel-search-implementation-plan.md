# 面板搜索功能 Implementation Plan

> **For AI:** REQUIRED SUB-SKILL: Use workflow-executing-plans to implement this plan task-by-task.

**Goal:** 在剪贴板历史面板与文本块面板的 header 增加搜索框，并对列表进行实时过滤；搜索框聚焦时快捷键依然可用；每次打开面板清空搜索并默认聚焦搜索框。

**Architecture:** 在 `ClipboardPanelViewModel` / `TextBlockPanelViewModel` 内引入 `searchQuery` 与 `filteredEntries`（分页/选择逻辑基于过滤结果集）。在两面板 UI 中增加 SwiftUI `TextField` 搜索框，并通过 `NSEvent.addLocalMonitorForEvents` 增加键盘命令 monitor，确保 `TextField` 聚焦时仍能触发 `Esc/Enter/↑↓/←→/⌘数字/⌘,`；同时对方向键修饰键与输入法组合输入做降噪，避免破坏中文输入体验。

**Tech Stack:** Swift 5 / SwiftUI / AppKit (`NSEvent`, `NSWindow`) / XCTest / `xcodebuildmcp`

---

## Prior Art

- 设计文档（已确认）：`docs/plans/2026-02-17-panel-search-design.md`
- 现有快捷键解析：`quicker/Panel/PanelKeyCommand.swift`
- 现有面板键盘捕获（兜底）：`quicker/Panel/KeyEventHandlingView.swift`
- 现有 ViewModel 单测：
  - `quickerTests/ClipboardPanelViewModelTests.swift`
  - `quickerTests/TextBlockPanelViewModelTests.swift`

---

### Task 1: Create Worktree (Recommended)

**Files:**

- None

**Step 1: Verify `.worktrees/` is ignored**

Run:

```bash
git check-ignore -q .worktrees && echo "OK: .worktrees ignored"
```

Expected: 输出 `OK: .worktrees ignored`。

**Step 2: Create a dedicated branch + worktree**

Run:

```bash
git worktree add -b codex/panel-search .worktrees/panel-search
```

Expected: 创建新目录 `.worktrees/panel-search`，并检出到新分支 `codex/panel-search`。

**Step 3: Verify status**

Run:

```bash
cd .worktrees/panel-search && git status --porcelain
```

Expected: no output (clean)。

**Step 4: Baseline tests (optional but recommended)**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker
```

Expected: 当前分支测试通过（如已有已知跳过项，按既有基线为准）。

---

### Task 2: Add Failing Tests for `TextBlockPanelViewModel` Search Filtering

**Files:**

- Modify: `quickerTests/TextBlockPanelViewModelTests.swift`

**Step 1: Update tests (write failing tests first)**

Update `quickerTests/TextBlockPanelViewModelTests.swift` to:

```swift
import XCTest
@testable import quicker

@MainActor
final class TextBlockPanelViewModelTests: XCTestCase {
    func testDefaultSelectionIsFirstItem() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make(title: "A"), make(title: "B")])
        XCTAssertEqual(vm.selectedEntry?.title, "A")
    }

    func testArrowDownAtLastItemFlipsPage() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: (0..<7).map { make(title: "\($0)") })
        vm.selectIndexInPage(4)
        vm.moveSelectionDown()
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedEntry?.title, "5")
    }

    func testCmdNumberMapping() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: [make(title: "A"), make(title: "B")])
        XCTAssertEqual(vm.entryForCmdNumber(2)?.title, "B")
        XCTAssertNil(vm.entryForCmdNumber(3))
    }

    func testSearchQueryFiltersByTitleOrContent() {
        let vm = TextBlockPanelViewModel(
            pageSize: 5,
            entries: [
                make(title: "Alpha", content: "first line"),
                make(title: "Beta", content: "contains KEY"),
                make(title: "KEY in title", content: "zzz"),
            ]
        )

        vm.searchQuery = "KEY"

        XCTAssertEqual(vm.visibleEntries.count, 2)
        XCTAssertEqual(vm.selectedEntry?.title, "Beta")
    }

    func testSearchQueryResetsPagingAndSelection() {
        let vm = TextBlockPanelViewModel(pageSize: 5, entries: (0..<9).map { make(title: "\($0)") })
        vm.nextPage()
        vm.selectIndexInPage(2)
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedIndexInPage, 2)

        vm.searchQuery = "1"

        XCTAssertEqual(vm.pageIndex, 0)
        XCTAssertEqual(vm.selectedIndexInPage, 0)
    }

    func testCmdNumberMappingUsesFilteredEntries() {
        let vm = TextBlockPanelViewModel(
            pageSize: 5,
            entries: [
                make(title: "A"),
                make(title: "B"),
                make(title: "C"),
            ]
        )

        vm.searchQuery = "B"

        XCTAssertEqual(vm.entryForCmdNumber(1)?.title, "B")
        XCTAssertNil(vm.entryForCmdNumber(2))
    }
}

private func make(title: String, content: String = "content") -> TextBlockPanelEntry {
    TextBlockPanelEntry(id: UUID(), title: title, content: content)
}
```

**Step 2: Run the test to verify it fails**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/TextBlockPanelViewModelTests"
```

Expected: FAIL（例如编译错误），类似 `Value of type 'TextBlockPanelViewModel' has no member 'searchQuery'` 或断言失败（过滤/重置逻辑未实现）。

**Step 3: Commit tests**

Run:

```bash
git add quickerTests/TextBlockPanelViewModelTests.swift
git commit -m "test(panel): 添加文本块搜索过滤测试"
```

---

### Task 3: Implement `TextBlockPanelViewModel` Search Filtering

**Files:**

- Modify: `quicker/TextBlock/TextBlockPanelViewModel.swift`
- Test: `quickerTests/TextBlockPanelViewModelTests.swift`

**Step 1: Implement minimal changes to pass tests**

Update `quicker/TextBlock/TextBlockPanelViewModel.swift` to:

```swift
@MainActor
final class TextBlockPanelViewModel: ObservableObject {
    let pageSize: Int

    @Published var searchQuery: String = "" {
        didSet { resetPagingForSearchIfNeeded(oldValue: oldValue) }
    }

    @Published private(set) var entries: [TextBlockPanelEntry]
    @Published private(set) var pageIndex: Int = 0
    @Published private(set) var selectedIndexInPage: Int = 0

    init(pageSize: Int = 5, entries: [TextBlockPanelEntry] = []) {
        self.pageSize = pageSize
        self.entries = entries
    }

    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredEntries: [TextBlockPanelEntry] {
        let query = normalizedSearchQuery
        guard query.isEmpty == false else { return entries }
        return entries.filter { entry in
            entry.title.localizedStandardContains(query) || entry.content.localizedStandardContains(query)
        }
    }

    var pageCount: Int { Pagination.pageCount(totalCount: filteredEntries.count, pageSize: pageSize) }

    var visibleRange: Range<Int> {
        Pagination.rangeForPage(pageIndex: pageIndex, totalCount: filteredEntries.count, pageSize: pageSize)
    }

    var visibleEntries: ArraySlice<TextBlockPanelEntry> { filteredEntries[visibleRange] }

    var selectedEntry: TextBlockPanelEntry? {
        let absolute = visibleRange.lowerBound + selectedIndexInPage
        guard absolute < filteredEntries.count else { return nil }
        return filteredEntries[absolute]
    }

    func setEntries(_ newEntries: [TextBlockPanelEntry]) {
        entries = newEntries
        searchQuery = ""
        pageIndex = 0
        selectedIndexInPage = 0
    }

    func moveSelectionUp() {
        guard filteredEntries.isEmpty == false else { return }
        if selectedIndexInPage > 0 {
            selectedIndexInPage -= 1
            return
        }
        guard pageIndex > 0 else { return }
        pageIndex -= 1
        selectedIndexInPage = max(0, visibleEntries.count - 1)
    }

    func moveSelectionDown() {
        guard filteredEntries.isEmpty == false else { return }
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
                totalCount: filteredEntries.count,
                pageSize: pageSize
            )
        else { return nil }
        return filteredEntries[absolute]
    }

    private func resetPagingForSearchIfNeeded(oldValue: String) {
        if oldValue == searchQuery { return }
        pageIndex = 0
        selectedIndexInPage = 0
    }
}
```

**Step 2: Re-run tests**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/TextBlockPanelViewModelTests"
```

Expected: PASS。

**Step 3: Commit**

Run:

```bash
git add quicker/TextBlock/TextBlockPanelViewModel.swift
git commit -m "feat(panel): 文本块面板支持搜索过滤"
```

---

### Task 4: Add Failing Tests for `ClipboardPanelViewModel` Search Filtering

**Files:**

- Modify: `quickerTests/ClipboardPanelViewModelTests.swift`

**Step 1: Update tests (write failing tests first)**

Append the following tests to `quickerTests/ClipboardPanelViewModelTests.swift`:

```swift
    func testSearchQueryFiltersByPreviewText() {
        let vm = ClipboardPanelViewModel(
            pageSize: 5,
            entries: [
                makeEntry("Alpha"),
                makeEntry("Beta KEY"),
                makeEntry("Gamma"),
            ]
        )

        vm.searchQuery = "KEY"

        XCTAssertEqual(vm.visibleEntries.count, 1)
        XCTAssertEqual(vm.selectedEntry?.previewText, "Beta KEY")
    }

    func testSearchQueryResetsPagingAndSelection() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: (0..<9).map { makeEntry("\($0)") })
        vm.nextPage()
        vm.selectIndexInPage(3)
        XCTAssertEqual(vm.pageIndex, 1)
        XCTAssertEqual(vm.selectedIndexInPage, 3)

        vm.searchQuery = "1"

        XCTAssertEqual(vm.pageIndex, 0)
        XCTAssertEqual(vm.selectedIndexInPage, 0)
    }

    func testCmdNumberMappingUsesFilteredEntries() {
        let vm = ClipboardPanelViewModel(pageSize: 5, entries: [makeEntry("A"), makeEntry("B"), makeEntry("C")])
        vm.searchQuery = "B"
        XCTAssertEqual(vm.entryForCmdNumber(1)?.previewText, "B")
        XCTAssertNil(vm.entryForCmdNumber(2))
    }
```

**Step 2: Run the test to verify it fails**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/ClipboardPanelViewModelTests"
```

Expected: FAIL（例如编译错误），类似 `Value of type 'ClipboardPanelViewModel' has no member 'searchQuery'` 或断言失败。

**Step 3: Commit tests**

Run:

```bash
git add quickerTests/ClipboardPanelViewModelTests.swift
git commit -m "test(panel): 添加剪贴板搜索过滤测试"
```

---

### Task 5: Implement `ClipboardPanelViewModel` Search Filtering

**Files:**

- Modify: `quicker/Panel/ClipboardPanelViewModel.swift`
- Test: `quickerTests/ClipboardPanelViewModelTests.swift`

**Step 1: Implement minimal changes to pass tests**

Update `quicker/Panel/ClipboardPanelViewModel.swift` to:

```swift
@MainActor
final class ClipboardPanelViewModel: ObservableObject {
    let pageSize: Int

    @Published var searchQuery: String = "" {
        didSet { resetPagingForSearchIfNeeded(oldValue: oldValue) }
    }

    @Published private(set) var entries: [ClipboardPanelEntry]
    @Published private(set) var pageIndex: Int = 0
    @Published private(set) var selectedIndexInPage: Int = 0

    init(pageSize: Int = 5, entries: [ClipboardPanelEntry] = []) {
        self.pageSize = pageSize
        self.entries = entries
    }

    private var normalizedSearchQuery: String {
        searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var filteredEntries: [ClipboardPanelEntry] {
        let query = normalizedSearchQuery
        guard query.isEmpty == false else { return entries }
        return entries.filter { $0.previewText.localizedStandardContains(query) }
    }

    var pageCount: Int { Pagination.pageCount(totalCount: filteredEntries.count, pageSize: pageSize) }

    var visibleRange: Range<Int> {
        Pagination.rangeForPage(pageIndex: pageIndex, totalCount: filteredEntries.count, pageSize: pageSize)
    }

    var visibleEntries: ArraySlice<ClipboardPanelEntry> { filteredEntries[visibleRange] }

    var selectedEntry: ClipboardPanelEntry? {
        let absoluteIndex = visibleRange.lowerBound + selectedIndexInPage
        guard absoluteIndex < filteredEntries.count else { return nil }
        return filteredEntries[absoluteIndex]
    }

    func setEntries(_ newEntries: [ClipboardPanelEntry]) {
        entries = newEntries
        searchQuery = ""
        pageIndex = 0
        selectedIndexInPage = 0
    }

    func moveSelectionUp() {
        guard filteredEntries.isEmpty == false else { return }

        if selectedIndexInPage > 0 {
            selectedIndexInPage -= 1
            return
        }

        guard pageIndex > 0 else { return }
        pageIndex -= 1
        selectedIndexInPage = max(0, visibleEntries.count - 1)
    }

    func moveSelectionDown() {
        guard filteredEntries.isEmpty == false else { return }

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

    func selectIndexInPage(_ index: Int) {
        let maxIndex = max(0, visibleEntries.count - 1)
        selectedIndexInPage = min(max(0, index), maxIndex)
    }

    func previousPage() {
        pageIndex = max(0, pageIndex - 1)
        selectedIndexInPage = 0
    }

    func nextPage() {
        pageIndex = min(max(0, pageCount - 1), pageIndex + 1)
        selectedIndexInPage = 0
    }

    func entryForCmdNumber(_ number: Int) -> ClipboardPanelEntry? {
        guard let absolute = Pagination.absoluteIndexForCmdNumber(cmdNumber: number, pageIndex: pageIndex, totalCount: filteredEntries.count, pageSize: pageSize) else {
            return nil
        }
        return filteredEntries[absolute]
    }

    private func resetPagingForSearchIfNeeded(oldValue: String) {
        if oldValue == searchQuery { return }
        pageIndex = 0
        selectedIndexInPage = 0
    }
}
```

**Step 2: Re-run tests**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker --extra-args "-only-testing:quickerTests/ClipboardPanelViewModelTests"
```

Expected: PASS。

**Step 3: Commit**

Run:

```bash
git add quicker/Panel/ClipboardPanelViewModel.swift
git commit -m "feat(panel): 剪贴板面板支持搜索过滤"
```

---

### Task 6: Add Panel Window Identifiers (So Monitors Can Scope Correctly)

**Files:**

- Create: `quicker/Panel/PanelWindowIdentifier.swift`
- Modify: `quicker/Panel/PanelController.swift`
- Modify: `quicker/TextBlock/TextBlockPanelController.swift`

**Step 1: Add identifiers**

Create `quicker/Panel/PanelWindowIdentifier.swift`:

```swift
import AppKit

enum PanelWindowIdentifier {
    static let clipboardPanel = NSUserInterfaceItemIdentifier("ClipboardPanel")
    static let textBlockPanel = NSUserInterfaceItemIdentifier("TextBlockPanel")
}
```

**Step 2: Assign identifier in clipboard panel controller**

In `quicker/Panel/PanelController.swift` inside `makePanel()`, after creating `panel`:

```swift
panel.identifier = PanelWindowIdentifier.clipboardPanel
```

**Step 3: Assign identifier in text block panel controller**

In `quicker/TextBlock/TextBlockPanelController.swift` inside `makePanel()`, after creating `panel`:

```swift
panel.identifier = PanelWindowIdentifier.textBlockPanel
```

**Step 4: Build**

Run:

```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected: Build succeeded。

**Step 5: Commit**

Run:

```bash
git add quicker/Panel/PanelController.swift quicker/TextBlock/TextBlockPanelController.swift quicker/Panel/PanelWindowIdentifier.swift
git commit -m "feat(panel): 为面板窗口设置 identifier"
```

---

### Task 7: Add `PanelKeyCommandMonitor` (Local KeyDown Monitor)

**Files:**

- Create: `quicker/Panel/PanelKeyCommandMonitor.swift`

**Step 1: Implement monitor view**

Create `quicker/Panel/PanelKeyCommandMonitor.swift`:

```swift
import AppKit
import SwiftUI

struct PanelKeyCommandMonitor: View {
    let panelIdentifier: NSUserInterfaceItemIdentifier
    let pageSize: Int
    let onCommand: (PanelKeyCommand) -> Bool

    @State private var monitorToken: Any?

    var body: some View {
        Color.clear
            .onAppear {
                if monitorToken != nil { return }
                monitorToken = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    guard shouldHandleEvent(event) else { return event }
                    guard let cmd = interpretCommand(for: event) else { return event }
                    let handled = onCommand(cmd)
                    return handled ? nil : event
                }
            }
            .onDisappear {
                if let token = monitorToken {
                    NSEvent.removeMonitor(token)
                    monitorToken = nil
                }
            }
    }

    private func shouldHandleEvent(_ event: NSEvent) -> Bool {
        guard let window = NSApp.keyWindow, window.isVisible else { return false }
        guard window.identifier == panelIdentifier else { return false }

        // Avoid hijacking text editing shortcuts.
        if isArrowKey(event), hasMovementModifiers(event) { return false }

        // Avoid breaking IME composing (marked text) for navigation/confirm.
        if isReturnKey(event) || isArrowKey(event) {
            if hasMarkedText(in: window) { return false }
        }

        return true
    }

    private func interpretCommand(for event: NSEvent) -> PanelKeyCommand? {
        let keyEvent = PanelKeyEvent(
            keyCode: UInt16(event.keyCode),
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            isCommandDown: event.modifierFlags.contains(.command)
        )
        return PanelKeyCommand.interpret(keyEvent, pageSize: pageSize)
    }

    private func isArrowKey(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 123, 124, 125, 126: return true
        default: return false
        }
    }

    private func isReturnKey(_ event: NSEvent) -> Bool {
        event.keyCode == 36
    }

    private func hasMovementModifiers(_ event: NSEvent) -> Bool {
        event.modifierFlags.contains(.command) || event.modifierFlags.contains(.option) || event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.control)
    }

    private func hasMarkedText(in window: NSWindow) -> Bool {
        if let textView = window.firstResponder as? NSTextView {
            return textView.hasMarkedText()
        }
        return false
    }
}
```

**Step 2: Build**

Run:

```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected: Build succeeded。

**Step 3: Commit**

Run:

```bash
git add quicker/Panel/PanelKeyCommandMonitor.swift
git commit -m "feat(panel): 增加面板键盘命令监控"
```

---

### Task 8: Add Search UI + Integrate Monitor in Both Panels

**Files:**

- Modify: `quicker/Panel/ClipboardPanelView.swift`
- Modify: `quicker/TextBlock/TextBlockPanelView.swift`

**Step 1: Clipboard panel UI changes**

In `quicker/Panel/ClipboardPanelView.swift`:

- Add `@FocusState private var isSearchFocused: Bool`
- Update `header` to include a second row search field:
  - `TextField("搜索", text: $viewModel.searchQuery)` + clear button
  - `.focused($isSearchFocused)`
- Add `PanelKeyCommandMonitor(panelIdentifier: PanelWindowIdentifier.clipboardPanel, pageSize: viewModel.pageSize, onCommand: handlePanelCommand)`
- Ensure focus on each show (key window becomes key):

```swift
.onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
    if NSApp.keyWindow?.identifier == PanelWindowIdentifier.clipboardPanel {
        isSearchFocused = true
    }
}
```

- Update empty state logic inside `content`:
  - If `viewModel.entries.isEmpty`: keep existing “暂无历史记录”
  - Else if `viewModel.filteredEntries.isEmpty`: show “无匹配结果”

Refactor existing `handleKeyDown(_:)` into:

- `private func handlePanelCommand(_ cmd: PanelKeyCommand) -> Bool`（switch 分支保持不变）
- `handleKeyDown(_:)` 仅负责 interpret + 调用 `handlePanelCommand(_:)`

**Step 2: Text block panel UI changes**

In `quicker/TextBlock/TextBlockPanelView.swift` similarly:

- Add `@FocusState private var isSearchFocused: Bool`
- Add search field binding to `$viewModel.searchQuery` + clear button
- Add `PanelKeyCommandMonitor(panelIdentifier: PanelWindowIdentifier.textBlockPanel, pageSize: viewModel.pageSize, onCommand: handlePanelCommand)`
- Add the same `NSWindow.didBecomeKeyNotification` focus logic (identifier 变为 `PanelWindowIdentifier.textBlockPanel`)
- Update empty state logic:
  - If `viewModel.entries.isEmpty`: keep existing “暂无文本块…”
  - Else if `viewModel.filteredEntries.isEmpty`: show “无匹配结果”
- Refactor command handling同上（`handlePanelCommand(_:)`）

**Step 3: Build**

Run:

```bash
xcodebuildmcp macos build --project-path ./quicker.xcodeproj --scheme quicker --configuration Debug
```

Expected: Build succeeded。

**Step 4: Manual smoke checks**

1. 打开剪贴板面板，输入 query，观察实时过滤；点击清除按钮恢复完整列表。
2. 搜索框聚焦时按 `↑↓/←→/Enter/⌘数字/⌘,`，确认均生效；`Esc` 直接关闭。
3. 打开文本块面板，验证 title 与 content 关键字都能命中。
4. 使用中文输入法进行组合输入（候选选择用方向键/回车），确认不会被 monitor 抢走（列表不应乱跳/不应触发粘贴）。

**Step 5: Commit**

Run:

```bash
git add quicker/Panel/ClipboardPanelView.swift quicker/TextBlock/TextBlockPanelView.swift
git commit -m "feat(panel): 面板增加搜索框"
```

---

### Task 9: Full Verification

**Files:**

- None

**Step 1: Run full tests**

Run:

```bash
xcodebuildmcp macos test --project-path ./quicker.xcodeproj --scheme quicker
```

Expected: PASS。

**Step 2: Optional build-and-run**

Run:

```bash
xcodebuildmcp macos build-and-run --project-path ./quicker.xcodeproj --scheme quicker
```

Expected: App launches; panels behave as designed.

---

## Execution Handoff

Plan complete and saved to `docs/plans/2026-02-17-panel-search-implementation-plan.md`. Two execution options:

1. Subagent-Driven (this session) — use **workflow-subagent-driven-development**（每个 Task 一个全新 subagent，逐步 review）
2. Parallel Session (separate) — open a new session and use **workflow-executing-plans**（按 Task 批次执行、带 checkpoint）

Which approach?

