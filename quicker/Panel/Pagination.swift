import Foundation

enum Pagination {
    static func pageCount(totalCount: Int, pageSize: Int) -> Int {
        guard totalCount > 0 else { return 0 }
        return Int(ceil(Double(totalCount) / Double(pageSize)))
    }

    static func rangeForPage(pageIndex: Int, totalCount: Int, pageSize: Int) -> Range<Int> {
        let start = max(0, pageIndex) * pageSize
        guard start < totalCount else { return 0..<0 }
        let end = min(totalCount, start + pageSize)
        return start..<end
    }

    static func absoluteIndexForCmdNumber(cmdNumber: Int, pageIndex: Int, totalCount: Int, pageSize: Int) -> Int? {
        guard (1...pageSize).contains(cmdNumber) else { return nil }
        let index = pageIndex * pageSize + (cmdNumber - 1)
        return index < totalCount ? index : nil
    }
}

