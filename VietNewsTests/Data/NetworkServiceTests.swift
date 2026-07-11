import XCTest
@testable import VietNews

final class NetworkServiceTests: XCTestCase {
    private let url = URL(string: "https://example.com/feed")!

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func test_given200Response_whenFetchingData_thenReturnsData() async throws {
        let expected = Data("hello".utf8)
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil
            )!
            return (response, expected)
        }
        let sut = URLSessionNetworkService(session: .mocked())

        let data = try await sut.data(from: url)

        XCTAssertEqual(data, expected)
    }

    func test_given404Response_whenFetchingData_thenThrowsInvalidResponse() async {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(
                url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil
            )!
            return (response, Data())
        }
        let sut = URLSessionNetworkService(session: .mocked())

        do {
            _ = try await sut.data(from: url)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .invalidResponse(statusCode: 404))
        }
    }
}
