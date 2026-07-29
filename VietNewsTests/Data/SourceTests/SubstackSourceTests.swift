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
        // given
        let sut = SubstackSource(
            network: StubNetworkService(), parser: StubRSSParser(),
            feeds: { [self.workFeed] }
        )
        let cases: [(NewsCategory, Language)] = [
            (.work, .english), (.work, .vietnamese), (.technology, .english), (.sport, .english)
        ]

        // when
        let supported = cases.map { sut.supports(category: $0.0, language: $0.1) }

        // then
        XCTAssertEqual(supported, [true, true, false, false])
    }

    func test_givenMultipleFeedsForCategory_whenFetching_thenRequestsAllAndMergesArticles() async throws {
        // given
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

        // when
        let requestedURLs = await network.requestedURLs

        // then
        XCTAssertEqual(requestedURLs.count, 2) // both technology feeds, not the work feed
        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].source, .substack)
        XCTAssertEqual(articles[0].category, .technology)
    }

    func test_givenFeedRequestFails_whenFetching_thenReturnsEmptyArticlesWithoutThrowing() async throws {
        // given
        let network = StubNetworkService()
        await network.setResult(.failure(NewsError.networkUnavailable))
        let sut = SubstackSource(
            network: network, parser: StubRSSParser(), feeds: { [self.techFeed] }
        )

        // when
        let articles = try await sut.fetch(category: .technology, language: .english)

        // then
        XCTAssertTrue(articles.isEmpty) // failure of individual substack feeds is non-fatal
    }
}
