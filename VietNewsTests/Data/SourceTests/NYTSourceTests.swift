import XCTest
@testable import VietNews

final class NYTSourceTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "nyt_world", withExtension: "json")
        )
        return try Data(contentsOf: url)
    }

    func test_givenEmptyAPIKey_whenCheckingSupport_thenReturnsFalse() {
        let sut = NYTSource(network: StubNetworkService(), apiKey: "")
        XCTAssertFalse(sut.supports(category: .world, language: .english))
    }

    func test_givenValidAPIKey_whenCheckingSupport_thenSupportsMappedEnglishCategories() {
        let sut = NYTSource(network: StubNetworkService(), apiKey: "key123")
        XCTAssertTrue(sut.supports(category: .world, language: .english))
        XCTAssertFalse(sut.supports(category: .world, language: .vietnamese))
        XCTAssertFalse(sut.supports(category: .game, language: .english))
    }

    func test_givenValidAPIKey_whenFetching_thenRequestsTopStoriesURLWithKey() async throws {
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData()))
        let sut = NYTSource(network: network, apiKey: "key123")

        _ = try await sut.fetch(category: .world, language: .english)

        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://api.nytimes.com/svc/topstories/v2/world.json?api-key=key123"
        )
    }

    func test_givenNYTTopStoriesJSON_whenFetching_thenMapsResultsToArticles() async throws {
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData()))
        let sut = NYTSource(network: network, apiKey: "key123")

        let articles = try await sut.fetch(category: .world, language: .english)

        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].title, "Global summit reaches accord")
        XCTAssertEqual(articles[0].summary, "Leaders agreed on a joint framework.")
        XCTAssertEqual(articles[0].imageURL?.absoluteString, "https://static01.nyt.com/images/summit.jpg")
        XCTAssertEqual(articles[0].source, .nyt)
        XCTAssertNil(articles[1].imageURL)
        XCTAssertNotNil(articles[0].publishedAt)
    }
}
