import XCTest
@testable import VietNews

final class SubstackSourceTests: XCTestCase {
    private let workFeed = SubstackFeed(
        url: URL(string: "https://www.lennysnewsletter.com/feed")!, category: .work
    )
    private let techFeed = SubstackFeed(
        url: URL(string: "https://newsletter.pragmaticengineer.com/feed")!, category: .technology
    )

    func test_givenConfiguredFeeds_whenCheckingSupport_thenOnlySupportsFeedCategories() {
        let sut = SubstackSource(
            network: StubNetworkService(), parser: StubRSSParser(),
            feeds: { [self.workFeed] }
        )
        XCTAssertTrue(sut.supports(category: .work, language: .english))
        XCTAssertTrue(sut.supports(category: .work, language: .vietnamese))
        XCTAssertFalse(sut.supports(category: .technology, language: .english))
        XCTAssertFalse(sut.supports(category: .sport, language: .english))
    }

    func test_givenMultipleFeedsForCategory_whenFetching_thenRequestsAllAndMergesArticles() async throws {
        let network = StubNetworkService()
        let parser = StubRSSParser()
        parser.items = [
            RSSItemDTO(
                title: "Post", link: URL(string: "https://sub.stack/p1")!,
                summary: "S", imageURL: nil, publishedAt: Date(timeIntervalSince1970: 1)
            )
        ]
        let secondTechFeed = SubstackFeed(
            url: URL(string: "https://other.substack.com/feed")!, category: .technology
        )
        let sut = SubstackSource(
            network: network, parser: parser,
            feeds: { [self.workFeed, self.techFeed, secondTechFeed] }
        )

        let articles = try await sut.fetch(category: .technology, language: .english)

        XCTAssertEqual(network.requestedURLs.count, 2) // both technology feeds, not the work feed
        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].source, .substack)
        XCTAssertEqual(articles[0].category, .technology)
    }

    func test_givenFeedRequestFails_whenFetching_thenReturnsEmptyArticlesWithoutThrowing() async throws {
        let network = StubNetworkService()
        network.result = .failure(NewsError.networkUnavailable)
        let sut = SubstackSource(
            network: network, parser: StubRSSParser(), feeds: { [self.techFeed] }
        )

        let articles = try await sut.fetch(category: .technology, language: .english)

        XCTAssertTrue(articles.isEmpty) // failure of individual substack feeds is non-fatal
    }
}
