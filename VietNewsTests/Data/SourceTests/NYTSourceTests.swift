import XCTest
@testable import VietNews

final class NYTSourceTests: XCTestCase {
    private func fixtureData(_ name: String = "nyt_world") throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: "json")
        )
        return try Data(contentsOf: url)
    }

    /// The retired sports section answers 200 with `results: null`. That is a section with no
    /// stories, not a broken response, and reporting it as a parse failure made a working
    /// endpoint look broken.
    func test_givenSectionWithNullResults_whenFetching_thenReturnsNoArticlesWithoutFailing() async throws {
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData("nyt_retired_section")))
        let sut = NYTSource(network: network, apiKey: "key123")

        let articles = try await sut.fetch(category: .world, language: .english)

        XCTAssertTrue(articles.isEmpty)
    }

    func test_givenRetiredSportsSection_whenCheckingSupport_thenNYTDoesNotClaimSport() {
        let sut = NYTSource(network: StubNetworkService(), apiKey: "key123")

        XCTAssertFalse(sut.supports(category: .sport, language: .english))
        XCTAssertTrue(sut.endpoints(category: .sport, language: .english).isEmpty)
    }

    func test_givenLiveSections_whenCheckingSupport_thenStillServesTheOnesThatWork() {
        let sut = NYTSource(network: StubNetworkService(), apiKey: "key123")

        for category in [NewsCategory.hotNews, .world, .finance, .technology, .car] {
            XCTAssertTrue(
                sut.supports(category: category, language: .english),
                "expected NYT to still serve \(category)"
            )
        }
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
