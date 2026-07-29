import XCTest
@testable import VietNews

private final class FakeHealthAdapter: NewsSourceAdapter {
    let source: NewsSource
    var result: Result<[Article], Error>

    init(source: NewsSource, result: Result<[Article], Error> = .success([])) {
        self.source = source
        self.result = result
    }

    func supports(category: NewsCategory, language: Language) -> Bool { true }
    func endpoints(category: NewsCategory, language: Language) -> [URL] {
        [URL(string: "https://example.com/\(source.rawValue)")!]
    }
    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        try result.get()
    }
}

final class SourceHealthRecordingTests: XCTestCase {
    private var health: MockSourceHealthRepository!

    override func setUp() {
        super.setUp()
        health = MockSourceHealthRepository()
    }

    private func makeSUT(_ adapters: [NewsSourceAdapter]) -> RemoteArticleRepository {
        RemoteArticleRepository(adapters: adapters, maxArticles: { 15 }, health: health)
    }

    func test_givenAFetch_whenOneSourceFails_thenEachOutcomeIsRecordedSeparately() async throws {
        let sut = makeSUT([
            FakeHealthAdapter(source: .bbc, result: .success([TestFactory.article(source: .bbc)])),
            FakeHealthAdapter(source: .nyt, result: .failure(NewsError.sourceTimeout(.nyt)))
        ])

        _ = try await sut.fetchArticles(category: .world, language: .english)

        XCTAssertNotNil(health.health(for: .builtIn(.bbc)).lastSucceededAt)
        XCTAssertNil(health.health(for: .builtIn(.bbc)).lastFailure)
        XCTAssertEqual(health.health(for: .builtIn(.nyt)).lastFailure, .timedOut)
    }

    func test_givenADisabledSource_whenFetching_thenItIsNeverAttempted() async throws {
        let disabled = FakeHealthAdapter(source: .nyt, result: .failure(NewsError.sourceTimeout(.nyt)))
        let sut = makeSUT([
            FakeHealthAdapter(source: .bbc, result: .success([TestFactory.article(source: .bbc)])),
            disabled
        ])
        health.setEnabled(false, for: .builtIn(.nyt))

        let result = try await sut.fetchArticles(category: .world, language: .english)

        // Not attempted is what stops it contributing failures: it cannot be reported as failing
        // if it was never asked, and its record is left as it was.
        XCTAssertEqual(result.failedSources, [])
        XCTAssertNil(health.health(for: .builtIn(.nyt)).lastFailure)
        XCTAssertEqual(result.articles.count, 1)
    }

    func test_givenEverySourceDisabled_whenFetching_thenItReportsNothingRatherThanFailing() async throws {
        let sut = makeSUT([FakeHealthAdapter(source: .bbc)])
        health.setEnabled(false, for: .builtIn(.bbc))

        let result = try await sut.fetchArticles(category: .world, language: .english)

        XCTAssertEqual(result.articles, [])
        XCTAssertEqual(result.failedSources, [])
    }

    func test_givenADisabledSourceIsSwitchedBackOn_whenFetching_thenItContributesAgain() async throws {
        let sut = makeSUT([FakeHealthAdapter(source: .bbc, result: .success([TestFactory.article(source: .bbc)]))])
        health.setEnabled(false, for: .builtIn(.bbc))
        _ = try await sut.fetchArticles(category: .world, language: .english)

        health.setEnabled(true, for: .builtIn(.bbc))
        let result = try await sut.fetchArticles(category: .world, language: .english)

        XCTAssertEqual(result.articles.count, 1)
    }
}

final class SubstackFeedHealthTests: XCTestCase {
    private let working = URL(string: "https://working.example.com/feed")!
    private let broken = URL(string: "https://broken.example.com/feed")!

    /// One adapter serves every feed the reader added, so a single `.substack` verdict could not
    /// say which of them is broken. Before this, the per-feed errors were swallowed outright.
    func test_givenTwoFeedsWhereOneFails_whenFetching_thenHealthIsRecordedPerFeed() async throws {
        let health = MockSourceHealthRepository()
        let network = RoutingNetworkService(failing: [broken])
        let parser = StubRSSParser()
        parser.items = [
            RSSItemDTO(
                title: "Post",
                link: URL(string: "https://working.example.com/p/1")!,
                summary: "Summary",
                imageURL: nil,
                publishedAt: Date(timeIntervalSince1970: 1)
            )
        ]
        let sut = SubstackSource(
            network: network,
            parser: parser,
            feeds: { [
                SubstackFeed(url: self.working, category: .technology),
                SubstackFeed(url: self.broken, category: .technology)
            ] },
            health: health
        )

        _ = try await sut.fetch(category: .technology, language: .english)

        XCTAssertNotNil(health.health(for: .userFeed(working)).lastSucceededAt)
        XCTAssertEqual(health.health(for: .userFeed(broken)).lastFailure, .unreachable)
    }

    func test_givenAFeedIsRead_whenItAnnouncesItsName_thenThatNameIsRemembered() async throws {
        let health = MockSourceHealthRepository()
        let parser = StubRSSParser()
        parser.channelTitle = "The Pragmatic Engineer"
        let sut = SubstackSource(
            network: RoutingNetworkService(failing: []),
            parser: parser,
            feeds: { [SubstackFeed(url: self.working, category: .technology)] },
            health: health
        )

        _ = try await sut.fetch(category: .technology, language: .english)

        XCTAssertEqual(health.health(for: .userFeed(working)).publicationTitle, "The Pragmatic Engineer")
    }

    func test_givenADisabledFeed_whenListingEndpoints_thenItIsExcluded() {
        let health = MockSourceHealthRepository()
        let sut = SubstackSource(
            network: RoutingNetworkService(failing: []),
            parser: StubRSSParser(),
            feeds: { [
                SubstackFeed(url: self.working, category: .technology),
                SubstackFeed(url: self.broken, category: .technology)
            ] },
            health: health
        )
        health.setEnabled(false, for: .userFeed(broken))

        XCTAssertEqual(sut.endpoints(category: .technology, language: .english), [working])
    }

    func test_givenEveryFeedInACategoryIsDisabled_whenAsked_thenItServesNothing() {
        let health = MockSourceHealthRepository()
        let sut = SubstackSource(
            network: RoutingNetworkService(failing: []),
            parser: StubRSSParser(),
            feeds: { [SubstackFeed(url: self.working, category: .technology)] },
            health: health
        )
        health.setEnabled(false, for: .userFeed(working))

        XCTAssertFalse(sut.supports(category: .technology, language: .english))
    }
}

/// Answers per URL, so one feed can fail while another succeeds in the same fetch.
private final class RoutingNetworkService: NetworkService, @unchecked Sendable {
    private let failing: Set<URL>

    init(failing: [URL]) {
        self.failing = Set(failing)
    }

    func data(from url: URL) async throws -> Data {
        if failing.contains(url) { throw URLError(.cannotConnectToHost) }
        return Data("<rss></rss>".utf8)
    }
}
