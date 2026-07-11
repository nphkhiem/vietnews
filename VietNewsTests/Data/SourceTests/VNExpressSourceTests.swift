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
        let sut = VNExpressSource.make(network: network, parser: parser)
        XCTAssertTrue(sut.supports(category: .sport, language: .vietnamese))
        XCTAssertTrue(sut.supports(category: .sport, language: .english))
    }

    func test_givenVietnameseLanguage_whenFetchingSport_thenRequestsVietnameseFeedURL() async throws {
        let sut = VNExpressSource.make(network: network, parser: parser)

        _ = try await sut.fetch(category: .sport, language: .vietnamese)

        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://vnexpress.net/rss/the-thao.rss"
        )
    }

    func test_givenEnglishLanguage_whenFetchingSport_thenRequestsEnglishFeedURL() async throws {
        let sut = VNExpressSource.make(network: network, parser: parser)

        _ = try await sut.fetch(category: .sport, language: .english)

        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://e.vnexpress.net/rss/sports.rss"
        )
    }

    func test_givenParsedRSSItems_whenFetching_thenMapsToArticles() async throws {
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

        let articles = try await sut.fetch(category: .sport, language: .vietnamese)

        XCTAssertEqual(articles.count, 2)
        XCTAssertEqual(articles[0].title, "T1")
        XCTAssertEqual(articles[0].source, .vnexpress)
        XCTAssertEqual(articles[0].category, .sport)
        XCTAssertEqual(articles[0].publishedAt, date)
        XCTAssertEqual(articles[1].publishedAt, .distantPast)
    }

    func test_givenUnmappedCategory_whenFetching_thenReturnsEmptyWithoutNetworkCall() async throws {
        // RSSFeedSource with a nil-returning mapping is simply unsupported
        let sut = RSSFeedSource(
            source: .vnexpress, network: network, parser: parser, feedURL: { _, _ in nil }
        )
        XCTAssertFalse(sut.supports(category: .game, language: .english))
        let articles = try await sut.fetch(category: .game, language: .english)
        XCTAssertTrue(articles.isEmpty)
        let requestedURLs = await network.requestedURLs
        XCTAssertTrue(requestedURLs.isEmpty)
    }

    func test_givenEnglishLanguage_whenCheckingSupportForCarSocialGame_thenReturnsFalseToAvoidDuplicateContent() {
        let sut = VNExpressSource.make(network: network, parser: parser)

        XCTAssertFalse(sut.supports(category: .car, language: .english))
        XCTAssertFalse(sut.supports(category: .social, language: .english))
        XCTAssertFalse(sut.supports(category: .game, language: .english))
        // Vietnamese is unaffected — .car/.social keep their distinct sections
        XCTAssertTrue(sut.supports(category: .car, language: .vietnamese))
        XCTAssertTrue(sut.supports(category: .social, language: .vietnamese))
    }
}
