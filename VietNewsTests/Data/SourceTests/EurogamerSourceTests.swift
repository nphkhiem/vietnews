import XCTest
@testable import VietNews

final class EurogamerSourceTests: XCTestCase {
    private var network: StubNetworkService!
    private var parser: StubRSSParser!

    override func setUp() {
        super.setUp()
        network = StubNetworkService()
        parser = StubRSSParser()
    }

    func test_givenGameCategoryEnglish_whenCheckingSupport_thenReturnsTrue() {
        // given
        let sut = EurogamerSource.make(network: network, parser: parser)

        // when
        let supported = sut.supports(category: .game, language: .english)

        // then
        XCTAssertTrue(supported)
    }

    func test_givenGameCategoryVietnamese_whenCheckingSupport_thenReturnsFalse() {
        // given
        let sut = EurogamerSource.make(network: network, parser: parser)

        // when
        let supported = sut.supports(category: .game, language: .vietnamese)

        // then
        XCTAssertFalse(supported)
    }

    func test_givenNonGameCategory_whenCheckingSupport_thenReturnsFalse() {
        // given
        let sut = EurogamerSource.make(network: network, parser: parser)

        // when
        let supported = sut.supports(category: .technology, language: .english)

        // then
        XCTAssertFalse(supported)
    }

    func test_givenGameCategoryEnglish_whenFetching_thenRequestsEurogamerFeedURL() async throws {
        // given
        let sut = EurogamerSource.make(network: network, parser: parser)

        // when
        _ = try await sut.fetch(category: .game, language: .english)

        // then
        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(requestedURLs.first?.absoluteString, "https://www.eurogamer.net/feed")
    }

    func test_givenParsedRSSItems_whenFetching_thenMapsToArticlesWithEurogamerSource() async throws {
        // given
        parser.items = [
            RSSItemDTO(
                title: "T1", link: URL(string: "https://www.eurogamer.net/article-1")!,
                summary: "S1", imageURL: nil, publishedAt: Date(timeIntervalSince1970: 1_000)
            )
        ]
        let sut = EurogamerSource.make(network: network, parser: parser)

        // when
        let articles = try await sut.fetch(category: .game, language: .english)

        // then
        XCTAssertEqual(articles.count, 1)
        XCTAssertEqual(articles[0].source, .eurogamer)
        XCTAssertEqual(articles[0].category, .game)
    }
}
