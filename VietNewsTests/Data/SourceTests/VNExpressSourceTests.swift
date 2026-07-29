import XCTest
@testable import VietNews

final class VNExpressSourceTests: XCTestCase {
    private var network: StubNetworkService!
    private var parser: StubRSSParser!

    override func setUp() {
        super.setUp()
        network = StubNetworkService()
        parser = StubRSSParser()
    }

    func test_givenSportCategory_whenCheckingSupport_thenSupportsBothLanguages() {
        // given
        let sut = VNExpressSource.make(network: network, parser: parser)

        // when
        let supported = [sut.supports(category: .sport, language: .vietnamese), sut.supports(category: .sport, language: .english)]

        // then
        XCTAssertEqual(supported, [true, true])
    }

    func test_givenVietnameseLanguage_whenFetchingSport_thenRequestsVietnameseFeedURL() async throws {
        // given
        let sut = VNExpressSource.make(network: network, parser: parser)

        // when
        _ = try await sut.fetch(category: .sport, language: .vietnamese)

        // then
        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://vnexpress.net/rss/the-thao.rss"
        )
    }

    func test_givenEnglishLanguage_whenFetchingSport_thenRequestsEnglishFeedURL() async throws {
        // given
        let sut = VNExpressSource.make(network: network, parser: parser)

        // when
        _ = try await sut.fetch(category: .sport, language: .english)

        // then
        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://e.vnexpress.net/rss/sports.rss"
        )
    }

    func test_givenParsedRSSItems_whenFetching_thenMapsToArticles() async throws {
        // given
        let date = Date(timeIntervalSince1970: 5_000)
        parser.items = [
            RSSItemDTO(
                title: "T1", link: URL(string: "https://vnexpress.net/a1.html")!,
                summary: "S1", imageURL: URL(string: "https://cdn/i.jpg"), publishedAt: date
            ),
            RSSItemDTO(
                title: "T2", link: URL(string: "https://vnexpress.net/a2.html")!,
                summary: "S2", imageURL: nil, publishedAt: nil // nil date → falls back to distantPast
            )
        ]
        let sut = VNExpressSource.make(network: network, parser: parser)

        // when
        let articles = try await sut.fetch(category: .sport, language: .vietnamese)

        // then
        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].title, "T1")
        XCTAssertEqual(articles[0].source, .vnexpress)
        XCTAssertEqual(articles[0].category, .sport)
        XCTAssertEqual(articles[0].publishedAt, date)
        XCTAssertNil(articles[1].publishedAt, "a missing feed date stays missing rather than becoming the year one")
    }

    func test_givenUnmappedCategory_whenFetching_thenReturnsEmptyWithoutNetworkCall() async throws {
        // given
        // RSSFeedSource with a nil-returning mapping is simply unsupported

        // when
        let sut = RSSFeedSource(
            source: .vnexpress, network: network, parser: parser, feedURL: { _, _ in nil }
        )

        // then
        XCTAssertFalse(sut.supports(category: .game, language: .english))
        let articles = try await sut.fetch(category: .game, language: .english)
        XCTAssertTrue(articles.isEmpty)
        let requestedURLs = await network.requestedURLs
        XCTAssertTrue(requestedURLs.isEmpty)
    }

    func test_givenEnglishLanguage_whenCheckingSupportForCarSocialGame_thenReturnsFalseToAvoidDuplicateContent() {
        // given
        let sut = VNExpressSource.make(network: network, parser: parser)
        let cases: [(NewsCategory, Language)] = [
            (.car, .english), (.social, .english), (.game, .english),
            (.car, .vietnamese), (.social, .vietnamese)
        ]

        // when
        let supported = cases.map { sut.supports(category: $0.0, language: $0.1) }

        // then
        // Vietnamese is unaffected: .car and .social keep their distinct sections there.
        XCTAssertEqual(supported, [false, false, false, true, true])
    }

    func test_givenVietnameseLanguage_whenCheckingSupportForGame_thenReturnsFalse() {
        // given
        let sut = VNExpressSource.make(network: network, parser: parser)

        // when
        let supported = sut.supports(category: .game, language: .vietnamese)

        // then
        XCTAssertFalse(supported)
    }
}
