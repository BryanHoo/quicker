import Combine
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
