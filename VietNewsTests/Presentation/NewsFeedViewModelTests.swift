import XCTest
@testable import VietNews

@MainActor
final class NewsFeedViewModelTests: XCTestCase {
    private var articleRepo: MockArticleRepository!
    private var cacheRepo: MockCacheRepository!
    private var preferences: UserPreferences!
    private var scheduler: MockRefreshScheduler!
    private var defaults: UserDefaults!
    private let suiteName = "NewsFeedViewModelTests"
    private let fixedNow = Date(timeIntervalSince1970: 100_000)

    override func setUp() {
        super.setUp()
        articleRepo = MockArticleRepository()
        cacheRepo = MockCacheRepository()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        preferences = UserPreferences(defaults: defaults)
        scheduler = MockRefreshScheduler()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSUT(isOnline: Bool = true) -> NewsFeedViewModel {
        NewsFeedViewModel(
            fetchNews: FetchNewsUseCase(
                articleRepository: articleRepo,
                cacheRepository: cacheRepo,
                now: { self.fixedNow }
            ),
            refreshNews: RefreshNewsUseCase(
                articleRepository: articleRepo,
                cacheRepository: cacheRepo,
                now: { self.fixedNow }
            ),
            preferences: preferences,
            scheduler: scheduler,
            now: { self.fixedNow },
            isOnline: { isOnline }
        )
    }

    func test_givenSuccessfulFetch_whenStarting_thenLoadsArticlesAndStartsScheduler() async {
        let articles = [TestFactory.article()]
        articleRepo.result = .success(FetchResult(articles: articles, failedSources: []))
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.articles, articles)
        XCTAssertEqual(scheduler.startedInterval, 300)
        XCTAssertEqual(articleRepo.lastLanguage, .vietnamese) // default
        XCTAssertEqual(articleRepo.lastCategory, .hotNews)
    }

    func test_givenEmptyFetchResult_whenStarting_thenShowsEmptyState() async {
        articleRepo.result = .success(FetchResult(articles: [], failedSources: []))
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.state, .empty)
    }

    func test_givenFetchFailureWithNoCache_whenStarting_thenShowsFailedState() async {
        articleRepo.result = .failure(NewsError.networkUnavailable)
        let sut = makeSUT()

        await sut.start()

        guard case .failed = sut.state else {
            return XCTFail("Expected failed state, got \(sut.state)")
        }
    }

    func test_givenPartialSourceFailure_whenStarting_thenExposesFailedSources() async {
        articleRepo.result = .success(
            FetchResult(articles: [TestFactory.article()], failedSources: [.bbc, .nyt])
        )
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.failedSources, [.bbc, .nyt])
    }

    func test_givenFreshlyFetchedArticles_whenApplied_thenDoesNotClaimTheDataIsStale() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()

        await sut.start()

        XCTAssertFalse(sut.isShowingStaleData, "seconds old data is not a staleness event")
    }

    func test_givenCachedArticlesOlderThanTheRefreshInterval_whenApplied_thenReportsStaleData() async {
        preferences.refreshInterval = 300
        let fetchedAt = fixedNow.addingTimeInterval(-400)
        cacheRepo.stored["hotNews_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fetchedAt,
            articleLimit: 15
        )
        articleRepo.result = .failure(NewsError.allSourcesFailed([.vnexpress], cause: .unreachable))
        let sut = makeSUT()

        await sut.start()

        XCTAssertTrue(sut.isShowingStaleData)
        XCTAssertEqual(sut.lastUpdated, fetchedAt)
    }

    /// The bug this replaces: a load moments after a successful fetch was served from cache and
    /// the interface announced the data was stale, over articles that were seconds old.
    func test_givenCacheHitMomentsAfterAFetch_whenApplied_thenDoesNotReportStaleData() async {
        preferences.refreshInterval = 300
        cacheRepo.stored["hotNews_vi"] = CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: fixedNow.addingTimeInterval(-5),
            articleLimit: 15
        )
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(articleRepo.fetchCallCount, 0, "expected this to be served from cache")
        XCTAssertFalse(sut.isShowingStaleData)
    }

    func test_givenDeviceOffline_whenLoadFails_thenSaysTheDeviceHasNoConnection() async {
        articleRepo.result = .failure(NewsError.allSourcesFailed([.vnexpress], cause: .unreachable))
        let sut = makeSUT(isOnline: false)

        await sut.start()

        XCTAssertEqual(sut.state, .failed("Không có kết nối mạng. Kiểm tra Wi-Fi hoặc dữ liệu di động."))
    }

    func test_givenDeviceOnlineAndSourcesTimedOut_whenLoadFails_thenSaysSourcesAreSlow() async {
        articleRepo.result = .failure(NewsError.allSourcesFailed([.vnexpress], cause: .timedOut))
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.state, .failed("Các nguồn tin phản hồi quá chậm. Thử lại sau ít phút."))
    }

    func test_givenDeviceOnlineAndSourcesRefused_whenLoadFails_thenSaysSourcesRefused() async {
        articleRepo.result = .failure(NewsError.allSourcesFailed([.nyt], cause: .rejected))
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.state, .failed("Nguồn tin từ chối yêu cầu. Có thể khả dụng lại sau."))
    }

    func test_givenDeviceOnlineAndResponsesUnreadable_whenLoadFails_thenSaysDataCouldNotBeRead() async {
        articleRepo.result = .failure(NewsError.allSourcesFailed([.nyt], cause: .unparseable))
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.state, .failed("Không đọc được dữ liệu từ nguồn tin."))
    }

    func test_givenMixedCauses_whenLoadFails_thenFallsBackToTheGenericMessage() async {
        articleRepo.result = .failure(NewsError.allSourcesFailed([.nyt, .bbc], cause: .mixed))
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.state, .failed("Không thể tải tin tức. Vui lòng thử lại."))
    }

    func test_givenEveryCause_whenComparingMessages_thenEachOneIsDistinct() async {
        var messages: Set<String> = []
        for cause in [SourceFailureCause.timedOut, .rejected, .unparseable, .unreachable, .mixed] {
            articleRepo.result = .failure(NewsError.allSourcesFailed([.vnexpress], cause: cause))
            let sut = makeSUT()
            await sut.start()
            guard case .failed(let message) = sut.state else {
                return XCTFail("Expected a failed state for \(cause)")
            }
            messages.insert(message)
        }

        XCTAssertEqual(messages.count, 5, "each cause must produce its own copy")
    }

    /// Previously a refresh that failed while articles were on screen produced no feedback at all.
    func test_givenArticlesOnScreen_whenRefreshFails_thenReportsItWithoutLosingTheArticles() async {
        let articles = [TestFactory.article()]
        articleRepo.result = .success(FetchResult(articles: articles, failedSources: []))
        let sut = makeSUT()
        await sut.start()

        articleRepo.result = .failure(NewsError.allSourcesFailed([.vnexpress], cause: .timedOut))
        await sut.refresh()

        XCTAssertEqual(sut.articles, articles)
        XCTAssertEqual(sut.state, .loaded)
        XCTAssertEqual(sut.refreshFailureMessage, "Các nguồn tin phản hồi quá chậm. Thử lại sau ít phút.")
    }

    func test_givenAReportedRefreshFailure_whenALaterLoadSucceeds_thenTheReportIsCleared() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()
        articleRepo.result = .failure(NewsError.allSourcesFailed([.vnexpress], cause: .timedOut))
        await sut.refresh()

        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        await sut.refresh()

        XCTAssertNil(sut.refreshFailureMessage)
    }

    func test_givenStartCalledTwice_whenSchedulerAlreadyArmed_thenSchedulerStartsOnce() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()

        await sut.start()
        await sut.start()

        XCTAssertEqual(scheduler.startCallCount, 1, "foregrounding must not re-arm the timer")
    }

    func test_givenStoppedFeed_whenStartingAgain_thenSchedulerIsArmedAgain() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()

        sut.stop()
        await sut.start()

        XCTAssertEqual(scheduler.startCallCount, 2)
    }

    /// The view starts the feed both when it appears and when the scene becomes active, which at
    /// launch happens within moments. Without coalescing that is two full fan-outs across every
    /// source, and the second one used to overwrite the first with a cache-shaped result.
    func test_givenTwoConcurrentLoads_whenOneIsAlreadyInFlight_thenOnlyOneFetchHappens() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        articleRepo.gateFetch(for: .hotNews)
        let sut = makeSUT()

        async let firstStart: Void = sut.start()
        while !articleRepo.didEnterGatedFetch {
            await Task.yield()
        }
        async let secondStart: Void = sut.start()
        for _ in 0..<10 {
            await Task.yield()
        }
        articleRepo.releaseGatedFetch()
        _ = await (firstStart, secondStart)

        XCTAssertEqual(articleRepo.fetchCallCount, 1)
    }

    func test_givenLoadInFlight_whenTimerTicks_thenTickJoinsInsteadOfFetchingAgain() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        articleRepo.gateFetch(for: .hotNews)
        let sut = makeSUT()

        async let running: Void = sut.start()
        while !articleRepo.didEnterGatedFetch {
            await Task.yield()
        }
        async let tick: Void = sut.load()
        for _ in 0..<10 {
            await Task.yield()
        }
        articleRepo.releaseGatedFetch()
        _ = await (running, tick)

        XCTAssertEqual(articleRepo.fetchCallCount, 1)
    }

    func test_givenNewCategory_whenSelected_thenLoadsArticlesForThatCategory() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()

        await sut.selectCategory(.finance)

        XCTAssertEqual(sut.selectedCategory, .finance)
        XCTAssertEqual(articleRepo.lastCategory, .finance)
    }

    func test_givenLanguageChange_whenSettingLanguage_thenPreservesCachePersistsAndReloads() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()

        await sut.setLanguage(.english)

        XCTAssertEqual(sut.language, .english)
        XCTAssertEqual(preferences.language, .english)
        XCTAssertEqual(cacheRepo.clearAllCallCount, 0, "the other language's cache must survive")
        XCTAssertEqual(articleRepo.lastLanguage, .english)
    }

    func test_givenRefreshFailure_whenRefreshing_thenKeepsExistingArticles() async {
        let articles = [TestFactory.article()]
        articleRepo.result = .success(FetchResult(articles: articles, failedSources: []))
        let sut = makeSUT()
        await sut.start()

        articleRepo.result = .failure(NewsError.networkUnavailable)
        await sut.refresh()

        XCTAssertEqual(sut.articles, articles)
        XCTAssertEqual(sut.state, .loaded)
    }

    func test_givenRunningScheduler_whenStopping_thenSchedulerStops() async {
        let sut = makeSUT()
        await sut.start()

        sut.stop()

        XCTAssertEqual(scheduler.stopCallCount, 1)
    }

    func test_givenSelectedCategory_whenPrefetchingAdjacent_thenWarmsNeighborCaches() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.selectCategory(.world) // neighbors in NewsCategory.allCases: sport and finance
        let callsBeforePrefetch = articleRepo.fetchCallCount

        await sut.prefetchAdjacentCategories()

        // Two neighbor fetches hit the repository (cache misses); results land in cache
        XCTAssertEqual(articleRepo.fetchCallCount, callsBeforePrefetch + 2)
        XCTAssertNotNil(cacheRepo.stored["sport_vi"])
        XCTAssertNotNil(cacheRepo.stored["finance_vi"])
        // Displayed articles unchanged - prefetch must not touch UI state
        XCTAssertEqual(sut.selectedCategory, .world)
    }

    func test_givenSlowStaleFetch_whenCategorySwitchedBeforeItResolves_thenStaleResultDoesNotOverwriteNewSelection() async {
        let hotArticles = [TestFactory.article(title: "Hot", category: .hotNews)]
        let sportArticles = [TestFactory.article(title: "Sport", category: .sport)]
        articleRepo.result = .success(FetchResult(articles: hotArticles, failedSources: []))
        articleRepo.gateFetch(for: .hotNews) // the initial hotNews load will suspend mid-flight
        let sut = makeSUT()

        let slowStart = Task { await sut.start() }

        // Let the slow hotNews fetch actually begin (i.e. reach the point where it's suspended
        // awaiting release) before switching categories, without relying on timing/sleeps.
        while !articleRepo.didEnterGatedFetch {
            await Task.yield()
        }

        // User switches to Sport while hotNews is still in flight; this fetch is not gated
        // and resolves immediately.
        articleRepo.result = .success(FetchResult(articles: sportArticles, failedSources: []))
        await sut.selectCategory(.sport)

        XCTAssertEqual(sut.selectedCategory, .sport)
        XCTAssertEqual(sut.articles, sportArticles)

        // Now let the stale hotNews fetch finally resolve.
        articleRepo.releaseGatedFetch()
        await slowStart.value

        // The late hotNews response must not have clobbered the currently displayed Sport articles.
        XCTAssertEqual(sut.selectedCategory, .sport)
        XCTAssertEqual(sut.articles, sportArticles)
    }

    func test_givenSelectedCategoryBecomesUnavailable_whenSettingLanguage_thenFallsBackToHotNews() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()
        await sut.setLanguage(.english)
        await sut.selectCategory(.game)
        await sut.setLanguage(.vietnamese) // .game becomes unavailable

        XCTAssertEqual(sut.selectedCategory, .hotNews)
    }

    func test_givenSelectedCategoryStaysAvailable_whenSettingLanguage_thenSelectionUnchanged() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()
        await sut.selectCategory(.finance)

        await sut.setLanguage(.english)

        XCTAssertEqual(sut.selectedCategory, .finance)
    }
}
