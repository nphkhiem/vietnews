import XCTest
@testable import VietNews

final class BBCSourceTests: XCTestCase {
    func test_givenBBCSource_whenCheckingSupport_thenOnlySupportsEnglish() {
        // given
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())

        // when
        let supported = [sut.supports(category: .world, language: .english), sut.supports(category: .world, language: .vietnamese)]

        // then
        XCTAssertEqual(supported, [true, false])
    }

    func test_givenUnmappedCategory_whenCheckingSupport_thenReturnsFalse() {
        // given
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())

        // when
        let supported = [sut.supports(category: .car, language: .english), sut.supports(category: .game, language: .english), sut.supports(category: .social, language: .english)]

        // then
        XCTAssertEqual(supported, [false, false, false])
    }

    func test_givenMappedCategories_whenAskingForEndpoints_thenReturnsVerifiedFeedPaths() {
        // given
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())
        let expected: [NewsCategory: String] = [
            .hotNews: "https://feeds.bbci.co.uk/news/rss.xml",
            .world: "https://feeds.bbci.co.uk/news/world/rss.xml",
            .finance: "https://feeds.bbci.co.uk/news/business/rss.xml",
            .technology: "https://feeds.bbci.co.uk/news/technology/rss.xml",
            .sport: "https://feeds.bbci.co.uk/sport/rss.xml"
        ]

        // when
        let actual = expected.keys.reduce(into: [NewsCategory: [String]]()) {
            $0[$1] = sut.endpoints(category: $1, language: .english).map(\.absoluteString)
        }

        // then
        for (category, url) in expected {
            XCTAssertEqual(actual[category], [url], "unexpected endpoint for \(category)")
        }
    }

    /// App Transport Security blocks cleartext requests, and `SubstackSource` style error
    /// swallowing would make that failure invisible, so the scheme is asserted rather than assumed.
    func test_givenEveryEndpoint_whenInspectingScheme_thenAllUseHTTPS() {
        // given
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())

        // when
        let endpoints = NewsCategory.allCases.flatMap { category in
            sut.endpoints(category: category, language: .english).map { (category, $0) }
        }

        // then
        for (category, url) in endpoints {
            XCTAssertEqual(url.scheme, "https", "\(category) endpoint is not https")
        }
    }

    func test_givenWorldCategory_whenFetching_thenRequestsWorldFeedURL() async throws {
        // given
        let network = StubNetworkService()
        let sut = BBCSource.make(network: network, parser: StubRSSParser())

        // when
        _ = try await sut.fetch(category: .world, language: .english)

        // then
        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://feeds.bbci.co.uk/news/world/rss.xml"
        )
    }
}
