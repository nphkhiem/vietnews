import XCTest
@testable import VietNews

final class BBCSourceTests: XCTestCase {
    func test_givenBBCSource_whenCheckingSupport_thenOnlySupportsEnglish() {
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())
        XCTAssertTrue(sut.supports(category: .world, language: .english))
        XCTAssertFalse(sut.supports(category: .world, language: .vietnamese))
    }

    func test_givenUnmappedCategory_whenCheckingSupport_thenReturnsFalse() {
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())
        XCTAssertFalse(sut.supports(category: .car, language: .english))
        XCTAssertFalse(sut.supports(category: .game, language: .english))
        XCTAssertFalse(sut.supports(category: .social, language: .english))
    }

    func test_givenMappedCategories_whenAskingForEndpoints_thenReturnsVerifiedFeedPaths() {
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())

        let expected: [NewsCategory: String] = [
            .hotNews: "https://feeds.bbci.co.uk/news/rss.xml",
            .world: "https://feeds.bbci.co.uk/news/world/rss.xml",
            .finance: "https://feeds.bbci.co.uk/news/business/rss.xml",
            .technology: "https://feeds.bbci.co.uk/news/technology/rss.xml",
            .sport: "https://feeds.bbci.co.uk/sport/rss.xml"
        ]

        for (category, url) in expected {
            XCTAssertEqual(
                sut.endpoints(category: category, language: .english).map(\.absoluteString),
                [url],
                "unexpected endpoint for \(category)"
            )
        }
    }

    /// App Transport Security blocks cleartext requests, and `SubstackSource` style error
    /// swallowing would make that failure invisible, so the scheme is asserted rather than assumed.
    func test_givenEveryEndpoint_whenInspectingScheme_thenAllUseHTTPS() {
        let sut = BBCSource.make(network: StubNetworkService(), parser: StubRSSParser())

        for category in NewsCategory.allCases {
            for url in sut.endpoints(category: category, language: .english) {
                XCTAssertEqual(url.scheme, "https", "\(category) endpoint is not https")
            }
        }
    }

    func test_givenWorldCategory_whenFetching_thenRequestsWorldFeedURL() async throws {
        let network = StubNetworkService()
        let sut = BBCSource.make(network: network, parser: StubRSSParser())

        _ = try await sut.fetch(category: .world, language: .english)

        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://feeds.bbci.co.uk/news/world/rss.xml"
        )
    }
}
