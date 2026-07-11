import XCTest
@testable import VietNews

final class NewsPipelineIntegrationTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        MockURLProtocol.handler = nil
        try super.tearDownWithError()
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: "xml"))
        return try Data(contentsOf: url)
    }

    private func makeUseCase() -> FetchNewsUseCase {
        let network = URLSessionNetworkService(session: .mocked())
        let adapter = VNExpressSource.make(network: network, parser: FeedKitRSSParser(parsingSource: .vnexpress))
        let repository = RemoteArticleRepository(adapters: [adapter])
        let cache = DiskCacheRepository(directory: tempDir)
        return FetchNewsUseCase(articleRepository: repository, cacheRepository: cache)
    }

    func test_givenLiveHTTPFixture_whenFetchingSportNews_thenPipelineParsesAndReturnsArticles() async throws {
        let xml = try fixtureData("vnexpress_sport")
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, xml)
        }
        let useCase = makeUseCase()

        let result = try await useCase.execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(result.articles.count, 2)
        XCTAssertEqual(result.articles.first?.title, "Việt Nam thắng trận mở màn")
        XCTAssertEqual(result.articles.first?.source, .vnexpress)
        XCTAssertFalse(result.isFromCache)
    }

    func test_givenCachedResultWithinTTL_whenFetchingAgain_thenMakesNoAdditionalNetworkRequests() async throws {
        let xml = try fixtureData("vnexpress_sport")
        var requestCount = 0
        MockURLProtocol.handler = { request in
            requestCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, xml)
        }
        let useCase = makeUseCase()
        _ = try await useCase.execute(category: .sport, language: .vietnamese)
        XCTAssertEqual(requestCount, 1)

        let second = try await useCase.execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(requestCount, 1) // no additional network call — served from disk cache
        XCTAssertTrue(second.isFromCache)
        XCTAssertEqual(second.articles.count, 2)
    }

    func test_givenHTTPFailureWithNoPriorCache_whenFetching_thenPropagatesNetworkUnavailable() async throws {
        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let useCase = makeUseCase()

        do {
            _ = try await useCase.execute(category: .sport, language: .vietnamese)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .networkUnavailable)
        }
    }
}
