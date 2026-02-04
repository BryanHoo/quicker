import XCTest
@testable import quicker

final class PaginationTests: XCTestCase {
    func testPageCount() {
        XCTAssertEqual(Pagination.pageCount(totalCount: 0, pageSize: 5), 0)
        XCTAssertEqual(Pagination.pageCount(totalCount: 1, pageSize: 5), 1)
        XCTAssertEqual(Pagination.pageCount(totalCount: 5, pageSize: 5), 1)
        XCTAssertEqual(Pagination.pageCount(totalCount: 6, pageSize: 5), 2)
    }

    func testSliceRange() {
        XCTAssertEqual(Pagination.rangeForPage(pageIndex: 0, totalCount: 12, pageSize: 5), 0..<5)
        XCTAssertEqual(Pagination.rangeForPage(pageIndex: 1, totalCount: 12, pageSize: 5), 5..<10)
        XCTAssertEqual(Pagination.rangeForPage(pageIndex: 2, totalCount: 12, pageSize: 5), 10..<12)
    }

    func testCmdNumberMapsToAbsoluteIndex() {
        // total 12 => pages: [0..4], [5..9], [10..11]
        XCTAssertEqual(Pagination.absoluteIndexForCmdNumber(cmdNumber: 1, pageIndex: 0, totalCount: 12, pageSize: 5), 0)
        XCTAssertEqual(Pagination.absoluteIndexForCmdNumber(cmdNumber: 5, pageIndex: 0, totalCount: 12, pageSize: 5), 4)
        XCTAssertEqual(Pagination.absoluteIndexForCmdNumber(cmdNumber: 3, pageIndex: 2, totalCount: 12, pageSize: 5), nil) // page 3 only has 2 items
    }
}

