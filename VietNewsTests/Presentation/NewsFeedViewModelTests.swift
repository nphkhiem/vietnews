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

    private func makeSUT() -> NewsFeedViewModel {
        NewsFeedViewModel(
            fetchNews: FetchNewsUseCase(articleRepository: articleRepo, cacheRepository: cacheRepo),
            refreshNews: RefreshNewsUseCase(articleRepository: articleRepo, cacheRepository: cacheRepo),
            cacheRepository: cacheRepo,
            preferences: preferences,
            scheduler: scheduler
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
            FetchResult(articles: [TestFactory.article()], failedSources: [.reuters, .nyt])
        )
        let sut = makeSUT()

        await sut.start()

        XCTAssertEqual(sut.failedSources, [.reuters, .nyt])
    }

    func test_givenNewCategory_whenSelected_thenLoadsArticlesForThatCategory() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()

        await sut.selectCategory(.finance)

        XCTAssertEqual(sut.selectedCategory, .finance)
        XCTAssertEqual(articleRepo.lastCategory, .finance)
    }

    func test_givenLanguageChange_whenSettingLanguage_thenClearsCachePersistsAndReloads() async {
        articleRepo.result = .success(FetchResult(articles: [TestFactory.article()], failedSources: []))
        let sut = makeSUT()
        await sut.start()

        await sut.setLanguage(.english)

        XCTAssertEqual(sut.language, .english)
        XCTAssertEqual(preferences.language, .english)
        XCTAssertEqual(cacheRepo.clearAllCallCount, 1)
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
        await sut.selectCategory(.world) // neighbors in NewsCategory.allCases: hotNews and finance
        let callsBeforePrefetch = articleRepo.fetchCallCount

        await sut.prefetchAdjacentCategories()

        // Two neighbor fetches hit the repository (cache misses); results land in cache
        XCTAssertEqual(articleRepo.fetchCallCount, callsBeforePrefetch + 2)
        XCTAssertNotNil(cacheRepo.stored["hotNews_vi"])
        XCTAssertNotNil(cacheRepo.stored["finance_vi"])
        // Displayed articles unchanged — prefetch must not touch UI state
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
}
