import Foundation
import XCTest
@testable import quicker

private final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("MockURLProtocol.requestHandler not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [MockURLProtocol.self]
    MockURLProtocol.requestHandler = handler
    return URLSession(configuration: configuration)
}

final class GitHubReleaseClientTests: XCTestCase {
    func testFetchLatestReleaseSuccess() async throws {
        defer { MockURLProtocol.requestHandler = nil }

        let session = makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            let json = """
            {
              "tag_name": "v1.0.0",
              "html_url": "https://example.com/release",
              "assets": [
                {
                  "name": "quicker-v1.0.0.dmg",
                  "browser_download_url": "https://example.com/dmg",
                  "size": 123
                }
              ]
            }
            """
            return (response, Data(json.utf8))
        }

        let client = GitHubReleaseClient(session: session, owner: "o", repo: "r")
        let release = try await client.fetchLatestRelease()

        XCTAssertEqual(release.tagName, "v1.0.0")
        XCTAssertEqual(release.assets.count, 1)
        XCTAssertEqual(release.assets[0].name, "quicker-v1.0.0.dmg")
    }

    func testFetchLatestReleaseHTTPStatusThrows() async {
        defer { MockURLProtocol.requestHandler = nil }

        let expectedBody = Data("rate limit".utf8)
        let session = makeSession { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, expectedBody)
        }

        let client = GitHubReleaseClient(session: session, owner: "o", repo: "r")

        do {
            _ = try await client.fetchLatestRelease()
            XCTFail("Expected error")
        } catch let error as GitHubReleaseClientError {
            switch error {
            case .httpStatus(let status, let data):
                XCTAssertEqual(status, 403)
                XCTAssertEqual(data, expectedBody)
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

