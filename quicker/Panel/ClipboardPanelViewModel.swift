import Combine
import Foundation

@MainActor
final class ClipboardPanelViewModel: ObservableObject {
    let pageSize: Int

    @Published private(set) var entries: [ClipboardPanelEntry]
    @Published private(set) var pageIndex: Int = 0
    @Published private(set) var selectedIndexInPage: Int = 0

    init(pageSize: Int = 5, entries: [ClipboardPanelEntry] = []) {
        self.pageSize = pageSize
        self.entries = entries
    }

    var pageCount: Int { Pagination.pageCount(totalCount: entries.count, pageSize: pageSize) }

    var visibleRange: Range<Int> {
        Pagination.rangeForPage(pageIndex: pageIndex, totalCount: entries.count, pageSize: pageSize)
    }

    var visibleEntries: ArraySlice<ClipboardPanelEntry> {
        entries[visibleRange]
    }

    var selectedEntry: ClipboardPanelEntry? {
        let absoluteIndex = visibleRange.lowerBound + selectedIndexInPage
        guard absoluteIndex < entries.count else { return nil }
        return entries[absoluteIndex]
    }

    func setEntries(_ newEntries: [ClipboardPanelEntry]) {
        entries = newEntries
        pageIndex = 0
        selectedIndexInPage = 0
    }

    func moveSelectionUp() {
        selectedIndexInPage = max(0, selectedIndexInPage - 1)
    }

    func moveSelectionDown() {
        let maxIndex = max(0, visibleEntries.count - 1)
        selectedIndexInPage = min(maxIndex, selectedIndexInPage + 1)
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
        guard let absolute = Pagination.absoluteIndexForCmdNumber(cmdNumber: number, pageIndex: pageIndex, totalCount: entries.count, pageSize: pageSize) else {
            return nil
        }
        return entries[absolute]
    }
}
