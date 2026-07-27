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

    private func makeSUT(ttl: TimeInterval = 300, articleLimit: Int = 15) -> FetchNewsUseCase {
        FetchNewsUseCase(
            articleRepository: articleRepo,
            cacheRepository: cacheRepo,
            ttl: ttl,
            now: { self.fixedNow },
            articleLimit: { articleLimit }
        )
    }

    func test_givenFreshCache_whenExecuting_thenReturnsCacheWithoutFetching() async throws {
        let cached = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-100), // 100s old, TTL 300
            articleLimit: 15
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
            fetchedAt: fixedNow.addingTimeInterval(-400), // stale
            articleLimit: 15
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
        articleRepo.result = .success(FetchResult(articles: fresh, failedSources: [.bbc]))

        let result = try await makeSUT().execute(category: .world, language: .english)

        XCTAssertEqual(result.articles, fresh)
        XCTAssertEqual(result.failedSources, [.bbc])
        XCTAssertEqual(articleRepo.lastCategory, .world)
        XCTAssertEqual(articleRepo.lastLanguage, .english)
        XCTAssertEqual(cacheRepo.saveCallCount, 1)
    }

    func test_givenFetchFailure_whenStaleCacheExists_thenFallsBackToStaleCache() async throws {
        let stale = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-9_000),
            articleLimit: 15
        )
        cacheRepo.stored["sport_vi"] = stale
        articleRepo.result = .failure(NewsError.allSourcesFailed([.vnexpress, .substack], cause: .unreachable))

        let result = try await makeSUT().execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(result.articles, stale.articles)
        XCTAssertTrue(result.isFromCache)
        XCTAssertEqual(result.lastUpdated, stale.fetchedAt)
        XCTAssertEqual(
            result.failedSources,
            [.vnexpress, .substack],
            "only the sources actually attempted may be named"
        )
    }

    func test_givenFetchFailureThatNamesNoSources_whenStaleCacheExists_thenNamesNoFailedSources() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-9_000),
            articleLimit: 15
        )
        articleRepo.result = .failure(NewsError.cacheFailed)

        let result = try await makeSUT().execute(category: .sport, language: .vietnamese)

        XCTAssertTrue(result.failedSources.isEmpty)
    }

    func test_givenCacheRecordingFailedSources_whenServedFromCache_thenReplaysThoseFailures() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-10),
            articleLimit: 15,
            failedSources: [.nyt]
        )

        let result = try await makeSUT().execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(articleRepo.fetchCallCount, 0)
        XCTAssertTrue(result.isFromCache)
        XCTAssertEqual(result.failedSources, [.nyt], "a cache hit must not claim everything worked")
    }

    func test_givenFetchWithPartialFailure_whenSaving_thenRecordsFailuresInCache() async throws {
        articleRepo.result = .success(
            FetchResult(articles: [TestFactory.article()], failedSources: [.nyt, .bbc])
        )

        _ = try await makeSUT().execute(category: .world, language: .english)

        XCTAssertEqual(cacheRepo.stored["world_en"]?.failedSources, [.nyt, .bbc])
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

    func test_givenFreshCacheUnderASmallerLimit_whenLimitGrows_thenRefetches() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-10),
            articleLimit: 15
        )
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))

        _ = try await makeSUT(articleLimit: 50).execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(articleRepo.fetchCallCount, 1)
        XCTAssertEqual(cacheRepo.stored["sport_vi"]?.articleLimit, 50)
    }

    func test_givenFreshCacheUnderALargerLimit_whenLimitShrinks_thenServesCache() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-10),
            articleLimit: 70
        )

        let result = try await makeSUT(articleLimit: 15).execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(articleRepo.fetchCallCount, 0)
        XCTAssertTrue(result.isFromCache)
    }

    /// Entries written before the limit was recorded cannot prove they satisfy any limit, so
    /// they are refetched once rather than trusted.
    func test_givenCacheWrittenBeforeLimitsWereRecorded_whenExecuting_thenRefetches() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-10)
        )
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))

        _ = try await makeSUT().execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(articleRepo.fetchCallCount, 1)
    }

    func test_givenCacheForOneLanguage_whenExecutingForAnotherLanguage_thenFetchesIndependently() async throws {
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-10),
            articleLimit: 15
        )
        articleRepo.result = .success(FetchResult(articles: [], failedSources: []))

        _ = try await makeSUT().execute(category: .sport, language: .english)

        XCTAssertEqual(articleRepo.fetchCallCount, 1) // vi cache must not serve en request
    }
}
