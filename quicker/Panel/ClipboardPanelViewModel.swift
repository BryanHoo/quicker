import Combine
import Foundation

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

    var visibleEntries: ArraySlice<ClipboardPanelEntry> {
        filteredEntries[visibleRange]
    }

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
