import XCTest
@testable import VietNews

private final class FakeAdapter: NewsSourceAdapter {
    let source: NewsSource
    var supported: Bool
    var result: Result<[Article], Error>
    var delay: TimeInterval

    init(
        source: NewsSource,
        supported: Bool = true,
        result: Result<[Article], Error> = .success([]),
        delay: TimeInterval = 0
    ) {
        self.source = source
        self.supported = supported
        self.result = result
        self.delay = delay
    }

    func supports(category: NewsCategory, language: Language) -> Bool { supported }

    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return try result.get()
    }
}

final class RemoteArticleRepositoryTests: XCTestCase {
    private func articles(_ count: Int, source: NewsSource, startingAt epoch: TimeInterval) -> [Article] {
        (0..<count).map { i in
            TestFactory.article(
                url: "https://\(source.rawValue).com/\(i)",
                source: source,
                publishedAt: Date(timeIntervalSince1970: epoch + TimeInterval(i))
            )
        }
    }

    func test_givenMultipleSuccessfulSources_whenFetching_thenMergesSortsAndCapsAt15() async throws {
        let a = FakeAdapter(source: .vnexpress, result: .success(articles(10, source: .vnexpress, startingAt: 1_000)))
        let b = FakeAdapter(source: .reddit, result: .success(articles(10, source: .reddit, startingAt: 2_000)))
        let sut = RemoteArticleRepository(adapters: [a, b])

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 15)
        XCTAssertTrue(result.failedSources.isEmpty)
        // newest first: all 10 reddit (epoch 2000+) precede vnexpress
        XCTAssertEqual(result.articles.first?.source, .reddit)
        let dates = result.articles.map(\.publishedAt)
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func test_givenOneSourceFails_whenFetching_thenReportsFailedSourceAndReturnsRest() async throws {
        let ok = FakeAdapter(source: .vnexpress, result: .success(articles(3, source: .vnexpress, startingAt: 1_000)))
        let bad = FakeAdapter(source: .reuters, result: .failure(NewsError.networkUnavailable))
        let sut = RemoteArticleRepository(adapters: [ok, bad])

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 3)
        XCTAssertEqual(result.failedSources, [.reuters])
    }

    func test_givenAllSourcesFail_whenFetching_thenThrowsNetworkUnavailable() async {
        let bad1 = FakeAdapter(source: .vnexpress, result: .failure(NewsError.networkUnavailable))
        let bad2 = FakeAdapter(source: .reuters, result: .failure(NewsError.networkUnavailable))
        let sut = RemoteArticleRepository(adapters: [bad1, bad2])

        do {
            _ = try await sut.fetchArticles(category: .sport, language: .english)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .networkUnavailable)
        }
    }

    func test_givenUnsupportedAdapter_whenFetching_thenSkipsWithoutCountingAsFailure() async throws {
        let unsupported = FakeAdapter(
            source: .nyt, supported: false, result: .failure(NewsError.networkUnavailable)
        )
        let ok = FakeAdapter(source: .reddit, result: .success(articles(2, source: .reddit, startingAt: 1_000)))
        let sut = RemoteArticleRepository(adapters: [unsupported, ok])

        let result = try await sut.fetchArticles(category: .game, language: .english)

        XCTAssertEqual(result.articles.count, 2)
        XCTAssertTrue(result.failedSources.isEmpty)
    }

    func test_givenNoSupportingAdapters_whenFetching_thenReturnsEmptyResult() async throws {
        let unsupported = FakeAdapter(source: .nyt, supported: false)
        let sut = RemoteArticleRepository(adapters: [unsupported])

        let result = try await sut.fetchArticles(category: .game, language: .vietnamese)

        XCTAssertTrue(result.articles.isEmpty)
        XCTAssertTrue(result.failedSources.isEmpty)
    }

    func test_givenSlowSource_whenExceedingTimeout_thenReportedAsFailedSource() async throws {
        let slow = FakeAdapter(
            source: .reuters,
            result: .success(articles(5, source: .reuters, startingAt: 9_000)),
            delay: 2.0
        )
        let fast = FakeAdapter(source: .reddit, result: .success(articles(2, source: .reddit, startingAt: 1_000)))
        let sut = RemoteArticleRepository(adapters: [slow, fast], perSourceTimeout: 0.2)

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 2)
        XCTAssertEqual(result.failedSources, [.reuters])
    }
}
