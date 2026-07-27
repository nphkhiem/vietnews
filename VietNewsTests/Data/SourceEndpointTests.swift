import XCTest
@testable import VietNews

/// Covers the endpoint each adapter would request, so URL construction is verifiable without
/// performing a fetch. The source health check relies on this to separate an unreachable
/// endpoint from one that returns unparseable content.
final class SourceEndpointTests: XCTestCase {
    private var network: StubNetworkService!
    private var parser: StubRSSParser!

    override func setUp() {
        super.setUp()
        network = StubNetworkService()
        parser = StubRSSParser()
    }

    private func allAdapters(nytKey: String = "test-key") -> [NewsSourceAdapter] {
        [
            VNExpressSource.make(network: network, parser: parser),
            BBCSource.make(network: network, parser: parser),
            EurogamerSource.make(network: network, parser: parser),
            RedditSource(network: network),
            NYTSource(network: network, apiKey: nytKey),
            SubstackSource(
                network: network,
                parser: parser,
                feeds: { [SubstackFeed(url: URL(string: "https://example.com/feed")!, category: .technology)] }
            )
        ]
    }

    func test_givenVNExpress_whenAskingForEndpoints_thenReturnsPerLanguageFeedURL() {
        let sut = VNExpressSource.make(network: network, parser: parser)

        XCTAssertEqual(
            sut.endpoints(category: .sport, language: .vietnamese).map(\.absoluteString),
            ["https://vnexpress.net/rss/the-thao.rss"]
        )
        XCTAssertEqual(
            sut.endpoints(category: .sport, language: .english).map(\.absoluteString),
            ["https://e.vnexpress.net/rss/sports.rss"]
        )
    }

    func test_givenVNExpress_whenCategoryHasNoSection_thenReturnsNoEndpoints() {
        let sut = VNExpressSource.make(network: network, parser: parser)

        XCTAssertTrue(sut.endpoints(category: .game, language: .vietnamese).isEmpty)
    }

    func test_givenEurogamer_whenAskingForEndpoints_thenOnlyServesEnglishGame() {
        let sut = EurogamerSource.make(network: network, parser: parser)

        XCTAssertEqual(
            sut.endpoints(category: .game, language: .english).map(\.absoluteString),
            ["https://www.eurogamer.net/feed"]
        )
        XCTAssertTrue(sut.endpoints(category: .game, language: .vietnamese).isEmpty)
        XCTAssertTrue(sut.endpoints(category: .sport, language: .english).isEmpty)
    }

    func test_givenReddit_whenAskingForEndpoints_thenOnlyServesEnglish() {
        let sut = RedditSource(network: network)

        XCTAssertEqual(
            sut.endpoints(category: .hotNews, language: .english).map(\.absoluteString),
            ["https://www.reddit.com/r/news/hot.json?limit=15"]
        )
        XCTAssertTrue(sut.endpoints(category: .hotNews, language: .vietnamese).isEmpty)
    }

    func test_givenNYTWithoutAPIKey_whenAskingForEndpoints_thenReturnsNothing() {
        let sut = NYTSource(network: network, apiKey: "")

        XCTAssertTrue(sut.endpoints(category: .world, language: .english).isEmpty)
    }

    func test_givenNYTWithAPIKey_whenAskingForEndpoints_thenReturnsSectionURL() {
        let sut = NYTSource(network: network, apiKey: "abc123")

        XCTAssertEqual(
            sut.endpoints(category: .world, language: .english).map(\.absoluteString),
            ["https://api.nytimes.com/svc/topstories/v2/world.json?api-key=abc123"]
        )
    }

    func test_givenSubstack_whenAskingForEndpoints_thenReturnsOnlyFeedsInThatCategory() {
        let work = SubstackFeed(url: URL(string: "https://a.example.com/feed")!, category: .work)
        let tech = SubstackFeed(url: URL(string: "https://b.example.com/feed")!, category: .technology)
        let sut = SubstackSource(network: network, parser: parser, feeds: { [work, tech] })

        XCTAssertEqual(sut.endpoints(category: .work, language: .vietnamese), [work.url])
        XCTAssertEqual(sut.endpoints(category: .technology, language: .english), [tech.url])
        XCTAssertTrue(sut.endpoints(category: .sport, language: .english).isEmpty)
    }

    /// The health check treats "has endpoints" and "claims support" as the same thing. If an
    /// adapter ever disagrees with itself, the check would silently skip a live endpoint.
    func test_givenEveryAdapter_whenComparingSupportAndEndpoints_thenTheyAgree() {
        for adapter in allAdapters() {
            for category in NewsCategory.allCases {
                for language in Language.allCases {
                    let hasEndpoints = !adapter.endpoints(category: category, language: language).isEmpty
                    XCTAssertEqual(
                        adapter.supports(category: category, language: language),
                        hasEndpoints,
                        "\(adapter.source) disagrees for \(category)/\(language)"
                    )
                }
            }
        }
    }

    func test_givenNYTWithoutAPIKey_whenComparingSupportAndEndpoints_thenBothReportNothing() {
        let sut = NYTSource(network: network, apiKey: "")

        for category in NewsCategory.allCases {
            XCTAssertFalse(sut.supports(category: category, language: .english))
            XCTAssertTrue(sut.endpoints(category: category, language: .english).isEmpty)
        }
    }
}
