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
            NYTSource(network: network, apiKey: nytKey),
            SubstackSource(
                network: network,
                parser: parser,
                feeds: { [SubstackFeed(url: URL(string: "https://example.com/feed")!, category: .technology)] }
            )
        ]
    }

    func test_givenVNExpress_whenAskingForEndpoints_thenReturnsPerLanguageFeedURL() {
        // given
        let sut = VNExpressSource.make(network: network, parser: parser)

        // when
        let endpoints = Language.allCases.map {
            sut.endpoints(category: .sport, language: $0).map(\.absoluteString)
        }

        // then
        XCTAssertEqual(endpoints, [
            ["https://vnexpress.net/rss/the-thao.rss"],
            ["https://e.vnexpress.net/rss/sports.rss"]
        ])
    }

    func test_givenVNExpress_whenCategoryHasNoSection_thenReturnsNoEndpoints() {
        // given
        let sut = VNExpressSource.make(network: network, parser: parser)

        // when
        let endpoints = sut.endpoints(category: .game, language: .vietnamese)

        // then
        XCTAssertTrue(endpoints.isEmpty)
    }

    func test_givenEurogamer_whenAskingForEndpoints_thenOnlyServesEnglishGame() {
        // given
        let sut = EurogamerSource.make(network: network, parser: parser)

        // when
        let englishGame = sut.endpoints(category: .game, language: .english)
        let vietnameseGame = sut.endpoints(category: .game, language: .vietnamese)
        let englishSport = sut.endpoints(category: .sport, language: .english)

        // then
        XCTAssertEqual(englishGame.map(\.absoluteString), ["https://www.eurogamer.net/feed"])
        XCTAssertTrue(vietnameseGame.isEmpty)
        XCTAssertTrue(englishSport.isEmpty)
    }

    func test_givenNYTWithoutAPIKey_whenAskingForEndpoints_thenReturnsNothing() {
        // given
        let sut = NYTSource(network: network, apiKey: "")

        // when
        let endpoints = sut.endpoints(category: .world, language: .english)

        // then
        XCTAssertTrue(endpoints.isEmpty)
    }

    func test_givenNYTWithAPIKey_whenAskingForEndpoints_thenReturnsSectionURL() {
        // given
        let sut = NYTSource(network: network, apiKey: "abc123")

        // when
        let endpoints = sut.endpoints(category: .world, language: .english)

        // then
        XCTAssertEqual(
            endpoints.map(\.absoluteString),
            ["https://api.nytimes.com/svc/topstories/v2/world.json?api-key=abc123"]
        )
    }

    func test_givenSubstack_whenAskingForEndpoints_thenReturnsOnlyFeedsInThatCategory() {
        // given
        let work = SubstackFeed(url: URL(string: "https://a.example.com/feed")!, category: .work)
        let tech = SubstackFeed(url: URL(string: "https://b.example.com/feed")!, category: .technology)

        let sut = SubstackSource(network: network, parser: parser, feeds: { [work, tech] })

        // when
        let workEndpoints = sut.endpoints(category: .work, language: .vietnamese)
        let techEndpoints = sut.endpoints(category: .technology, language: .english)
        let sportEndpoints = sut.endpoints(category: .sport, language: .english)

        // then
        XCTAssertEqual(workEndpoints, [work.url])
        XCTAssertEqual(techEndpoints, [tech.url])
        XCTAssertTrue(sportEndpoints.isEmpty)
    }

    /// The health check treats "has endpoints" and "claims support" as the same thing. If an
    /// adapter ever disagrees with itself, the check would silently skip a live endpoint.
    func test_givenEveryAdapter_whenComparingSupportAndEndpoints_thenTheyAgree() {
        // given
        let combinations = allAdapters().flatMap { adapter in
            NewsCategory.allCases.flatMap { category in
                Language.allCases.map { (adapter, category, $0) }
            }
        }

        // when
        let verdicts = combinations.map { adapter, category, language in
            (
                adapter, category, language,
                adapter.supports(category: category, language: language),
                !adapter.endpoints(category: category, language: language).isEmpty
            )
        }

        // then
        for (adapter, category, language, claimsSupport, hasEndpoints) in verdicts {
            XCTAssertEqual(
                claimsSupport,
                hasEndpoints,
                "\(adapter.source) disagrees for \(category)/\(language)"
            )
        }
    }

    func test_givenNYTWithoutAPIKey_whenComparingSupportAndEndpoints_thenBothReportNothing() {
        // given
        let sut = NYTSource(network: network, apiKey: "")

        // when
        let verdicts = NewsCategory.allCases.map {
            (sut.supports(category: $0, language: .english), sut.endpoints(category: $0, language: .english))
        }

        // then
        XCTAssertTrue(verdicts.allSatisfy { !$0.0 })
        XCTAssertTrue(verdicts.allSatisfy { $0.1.isEmpty })
    }
}
