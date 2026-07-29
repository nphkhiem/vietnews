import XCTest
@testable import VietNews

final class NetworkHardeningTests: XCTestCase {
    private let url = URL(string: "https://example.com/feed")!

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    private func respondOK(capturing captured: @escaping (URLRequest) -> Void) {
        MockURLProtocol.handler = { request in
            captured(request)
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, Data("ok".utf8))
        }
    }

    /// Publishers block or throttle clients they cannot identify, and an unnamed reader has no
    /// way to be contacted before being cut off.
    func test_givenARequest_whenSent_thenItIdentifiesTheApp() async throws {
        // given
        var sent: URLRequest?
        respondOK { sent = $0 }
        let sut = URLSessionNetworkService(session: .mocked(), userAgent: "VietNews/1.0 (+url)")

        // when
        _ = try await sut.data(from: url)

        // then
        XCTAssertEqual(sent?.value(forHTTPHeaderField: "User-Agent"), "VietNews/1.0 (+url)")
    }

    func test_givenTheDefaultUserAgent_whenBuilt_thenItNamesTheAppAndItsVersion() {
        // given
        let sut = URLSessionNetworkService.self

        // when
        let agent = sut.defaultUserAgent()

        // then
        XCTAssertTrue(agent.contains("/"), "expected a name and version, got: \(agent)")
        XCTAssertTrue(agent.contains("http"), "expected a contact address, got: \(agent)")
    }

    /// Without an explicit timeout a request inherits sixty seconds, so the repository's own ten
    /// second budget only ever abandoned a request that carried on running.
    func test_givenARequest_whenSent_thenItCarriesAnExplicitTimeout() async throws {
        // given
        var sent: URLRequest?
        respondOK { sent = $0 }
        let sut = URLSessionNetworkService(session: .mocked(), timeout: 10)

        // when
        _ = try await sut.data(from: url)

        // then
        XCTAssertEqual(sent?.timeoutInterval, 10)
    }

    func test_givenTheDefaultTimeout_whenCompared_thenItMatchesThePerSourceBudget() {
        // given
        let perSourceBudget: TimeInterval = 10

        // when
        let defaultTimeout = URLSessionNetworkService.defaultTimeout

        // then
        XCTAssertEqual(defaultTimeout, perSourceBudget)
    }

    /// A reader was previously told the server answered with status -1, which is not a thing.
    func test_givenANonHTTPResponse_whenFetching_thenItReportsANamedError() async {
        // given
        MockURLProtocol.handler = { request in
            (URLResponse(url: request.url!, mimeType: nil, expectedContentLength: 0, textEncodingName: nil), Data())
        }
        let sut = URLSessionNetworkService(session: .mocked())

        // when
        let thrown = await errorThrown { _ = try await sut.data(from: self.url) }

        // then
        XCTAssertEqual(thrown as? NewsError, .nonHTTPResponse)
    }

    func test_givenANonHTTPResponse_whenClassified_thenItReadsAsUnreadable() {
        // given
        let error = NewsError.nonHTTPResponse

        // when
        let cause = SourceFailureCause(error)

        // then
        XCTAssertEqual(cause, .unparseable)
    }
}
