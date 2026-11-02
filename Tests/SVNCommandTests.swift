import XCTest

final class SVNCommandTests: XCTestCase {
    func testRequestRoundTripPreservesOperationAndPaths() throws {
        let request = SVNCommandRequest(
            operation: .status,
            paths: [
                "/Users/test/working copy",
                "/Users/test/中文目录/file.txt"
            ]
        )

        let url = try XCTUnwrap(request.url)
        XCTAssertEqual(SVNCommandRequest(url: url), request)
    }

    func testEveryOperationRoundTrips() throws {
        for operation in SVNOperation.allCases {
            let request = SVNCommandRequest(
                operation: operation,
                paths: ["/tmp/working-copy"]
            )

            XCTAssertEqual(
                SVNCommandRequest(url: try XCTUnwrap(request.url)),
                request
            )
        }
    }

    func testRejectsUnknownOperation() {
        let url = URL(
            string: "svn-finder://run?operation=unknown&path=/tmp/example"
        )!

        XCTAssertNil(SVNCommandRequest(url: url))
    }

    func testRejectsRequestWithoutPath() {
        let url = URL(string: "svn-finder://run?operation=status")!

        XCTAssertNil(SVNCommandRequest(url: url))
    }
}
