import XCTest
@testable import VietNews

final class ReutersSourceTests: XCTestCase {
    func test_givenReutersSource_whenCheckingSupport_thenOnlySupportsEnglish() {
        let sut = ReutersSource.make(network: StubNetworkService(), parser: StubRSSParser())
        XCTAssertTrue(sut.supports(category: .world, language: .english))
        XCTAssertFalse(sut.supports(category: .world, language: .vietnamese))
    }

    func test_givenUnmappedCategory_whenCheckingSupport_thenReturnsFalse() {
        let sut = ReutersSource.make(network: StubNetworkService(), parser: StubRSSParser())
        XCTAssertFalse(sut.supports(category: .car, language: .english))
        XCTAssertFalse(sut.supports(category: .game, language: .english))
    }

    func test_givenWorldCategory_whenFetching_thenRequestsTopNewsTopicURL() async throws {
        let network = StubNetworkService()
        let sut = ReutersSource.make(network: network, parser: StubRSSParser())

        _ = try await sut.fetch(category: .world, language: .english)

        let requestedURLs = await network.requestedURLs
        XCTAssertEqual(
            requestedURLs.first?.absoluteString,
            "https://www.reutersagency.com/feed/?best-topics=top-news&post_type=best"
        )
    }
}
