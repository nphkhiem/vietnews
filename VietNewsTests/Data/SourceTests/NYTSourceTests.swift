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
        // given
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData("nyt_retired_section")))
        let sut = NYTSource(network: network, apiKey: "key123")

        // when
        let articles = try await sut.fetch(category: .world, language: .english)

        // then
        XCTAssertTrue(articles.isEmpty)
    }

    func test_givenRetiredSportsSection_whenCheckingSupport_thenNYTDoesNotClaimSport() {
        // given
        let sut = NYTSource(network: StubNetworkService(), apiKey: "key123")

        // when
        let claimsSport = sut.supports(category: .sport, language: .english)
        let sportEndpoints = sut.endpoints(category: .sport, language: .english)

        // then
        XCTAssertFalse(claimsSport)
        XCTAssertTrue(sportEndpoints.isEmpty)
    }

    func test_givenLiveSections_whenCheckingSupport_thenStillServesTheOnesThatWork() {
        // given
        let sut = NYTSource(network: StubNetworkService(), apiKey: "key123")
        let live: [NewsCategory] = [.hotNews, .world, .finance, .technology, .car]

        // when
        let supported = live.map { ($0, sut.supports(category: $0, language: .english)) }

        // then
        for (category, claimsSupport) in supported {
            XCTAssertTrue(claimsSupport, "expected NYT to still serve \(category)")
        }
    }

    func test_givenEmptyAPIKey_whenCheckingSupport_thenReturnsFalse() {
        // given
        let sut = NYTSource(network: StubNetworkService(), apiKey: "")

        // when
        let supported = sut.supports(category: .world, language: .english)

        // then
        XCTAssertFalse(supported)
    }

    func test_givenValidAPIKey_whenCheckingSupport_thenSupportsMappedEnglishCategories() {
        // given
        let sut = NYTSource(network: StubNetworkService(), apiKey: "key123")

        // when
        let supported = [sut.supports(category: .world, language: .english), sut.supports(category: .world, language: .vietnamese), sut.supports(category: .game, language: .english)]

        // then
        XCTAssertEqual(supported, [true, false, false])
    }

    func test_givenValidAPIKey_whenFetching_thenRequestsTopStoriesURLWithKey() async throws {
        // given
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData()))
        let sut = NYTSource(network: network, apiKey: "key123")

        // when
        _ = try await sut.fetch(category: .world, language: .english)

        // then
        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://api.nytimes.com/svc/topstories/v2/world.json?api-key=key123"
        )
    }

    func test_givenNYTTopStoriesJSON_whenFetching_thenMapsResultsToArticles() async throws {
        // given
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData()))
        let sut = NYTSource(network: network, apiKey: "key123")

        // when
        let articles = try await sut.fetch(category: .world, language: .english)

        // then
        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].title, "Global summit reaches accord")
        XCTAssertEqual(articles[0].summary, "Leaders agreed on a joint framework.")
        XCTAssertEqual(articles[0].imageURL?.absoluteString, "https://static01.nyt.com/images/summit.jpg")
        XCTAssertEqual(articles[0].source, .nyt)
        XCTAssertNil(articles[1].imageURL)
        XCTAssertNotNil(articles[0].publishedAt)
    }
}
