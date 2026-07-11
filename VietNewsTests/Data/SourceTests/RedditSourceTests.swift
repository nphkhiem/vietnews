import XCTest
@testable import VietNews

final class RedditSourceTests: XCTestCase {
    private func fixtureData() throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: "reddit_technology", withExtension: "json")
        )
        return try Data(contentsOf: url)
    }

    func test_givenMappedCategory_whenCheckingSupport_thenOnlySupportsEnglish() {
        let sut = RedditSource(network: StubNetworkService())
        XCTAssertTrue(sut.supports(category: .technology, language: .english))
        XCTAssertTrue(sut.supports(category: .technology, language: .vietnamese) == false)
        XCTAssertTrue(sut.supports(category: .social, language: .english)) // r/vietnam
    }

    func test_givenTechnologyCategory_whenFetching_thenRequestsHotJSONForSubreddit() async throws {
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData()))
        let sut = RedditSource(network: network)

        _ = try await sut.fetch(category: .technology, language: .english)

        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://www.reddit.com/r/technology/hot.json?limit=15"
        )
    }

    func test_givenRedditListingJSON_whenFetching_thenMapsPostsToArticles() async throws {
        let network = StubNetworkService()
        await network.setResult(.success(try fixtureData()))
        let sut = RedditSource(network: network)

        let articles = try await sut.fetch(category: .technology, language: .english)

        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].title, "New chip breaks efficiency record")
        XCTAssertEqual(
            articles[0].url.absoluteString,
            "https://www.reddit.com/r/technology/comments/abc123/new_chip/"
        )
        XCTAssertEqual(articles[0].imageURL?.absoluteString, "https://b.thumbs.redditmedia.com/thumb1.jpg")
        XCTAssertEqual(articles[0].publishedAt, Date(timeIntervalSince1970: 1_783_989_000))
        XCTAssertEqual(articles[0].source, .reddit)
        XCTAssertNil(articles[1].imageURL) // "self" thumbnail is not a URL
        XCTAssertEqual(articles[1].summary, "Looking for recommendations under $1500.")
    }
}
