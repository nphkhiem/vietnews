import XCTest
@testable import VietNews

final class FetchNewsUseCaseTests: XCTestCase {
    private var articleRepo: MockArticleRepository!
    private var cacheRepo: MockCacheRepository!
    private let fixedNow = Date(timeIntervalSince1970: 10_000)

    override func setUp() {
        super.setUp()
        articleRepo = MockArticleRepository()
        cacheRepo = MockCacheRepository()
    }

    private func makeSUT(ttl: TimeInterval = 300) -> FetchNewsUseCase {
        FetchNewsUseCase(
            articleRepository: articleRepo,
            cacheRepository: cacheRepo,
            ttl: ttl,
            now: { self.fixedNow }
        )
    }

    func test_givenFreshCache_whenExecuting_thenReturnsCacheWithoutFetching() async throws {
        let cached = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-100) // 100s old, TTL 300
        )
        cacheRepo.stored["sport_vi"] = cached

        let result = try await makeSUT().execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(articleRepo.fetchCallCount, 0)
        XCTAssertEqual(result.articles, cached.articles)
        XCTAssertTrue(result.isFromCache)
        XCTAssertEqual(result.lastUpdated, cached.fetchedAt)
    }

    func test_givenStaleCache_whenExecuting_thenFetchesAndSavesToCache() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article(url: "https://old.com/1")],
            fetchedAt: fixedNow.addingTimeInterval(-400) // stale
        )
        let fresh = [TestFactory.article(url: "https://new.com/1")]
        articleRepo.result = .success(FetchResult(articles: fresh, failedSources: []))

        let result = try await makeSUT().execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(articleRepo.fetchCallCount, 1)
        XCTAssertEqual(result.articles, fresh)
        XCTAssertFalse(result.isFromCache)
        XCTAssertEqual(cacheRepo.saveCallCount, 1)
        XCTAssertEqual(cacheRepo.stored["sport_vi"]?.articles, fresh)
    }

    func test_givenNoCache_whenExecuting_thenFetchesAndSaves() async throws {
        let fresh = [TestFactory.article()]
        articleRepo.result = .success(FetchResult(articles: fresh, failedSources: [.reuters]))

        let result = try await makeSUT().execute(category: .world, language: .english)

        XCTAssertEqual(result.articles, fresh)
        XCTAssertEqual(result.failedSources, [.reuters])
        XCTAssertEqual(articleRepo.lastCategory, .world)
        XCTAssertEqual(articleRepo.lastLanguage, .english)
        XCTAssertEqual(cacheRepo.saveCallCount, 1)
    }

    func test_givenFetchFailure_whenStaleCacheExists_thenFallsBackToStaleCache() async throws {
        let stale = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-9_000)
        )
        cacheRepo.stored["sport_vi"] = stale
        articleRepo.result = .failure(NewsError.networkUnavailable)

        let result = try await makeSUT().execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(result.articles, stale.articles)
        XCTAssertTrue(result.isFromCache)
        XCTAssertEqual(result.lastUpdated, stale.fetchedAt)
        XCTAssertEqual(result.failedSources, NewsSource.allCases)
    }

    func test_givenFetchFailure_whenNoCacheExists_thenRethrowsError() async {
        articleRepo.result = .failure(NewsError.networkUnavailable)

        do {
            _ = try await makeSUT().execute(category: .sport, language: .vietnamese)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .networkUnavailable)
        }
    }

    func test_givenCacheForOneLanguage_whenExecutingForAnotherLanguage_thenFetchesIndependently() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-10)
        )
        articleRepo.result = .success(FetchResult(articles: [], failedSources: []))

        _ = try await makeSUT().execute(category: .sport, language: .english)

        XCTAssertEqual(articleRepo.fetchCallCount, 1) // vi cache must not serve en request
    }
}
