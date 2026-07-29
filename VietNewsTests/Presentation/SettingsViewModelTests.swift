import XCTest
@testable import VietNews

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var preferences: UserPreferences!
    private var scheduler: MockRefreshScheduler!
    private var cacheRepo: MockCacheRepository!
    private var defaults: UserDefaults!
    private let suiteName = "SettingsViewModelTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        preferences = UserPreferences(defaults: defaults)
        scheduler = MockRefreshScheduler()
        cacheRepo = MockCacheRepository()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSUT() -> SettingsViewModel {
        SettingsViewModel(
            preferences: preferences,
            scheduler: scheduler,
            cacheRepository: cacheRepo,
            sourceHealth: MockSourceHealthRepository(),
            serves: { _, _ in true },
            network: StubNetworkService(),
            parser: StubRSSParser()
        )
    }

    func test_givenStoredPreferences_whenInitializing_thenLoadsInitialValues() {
        // given
        preferences.refreshInterval = 900

        // when
        let sut = makeSUT()

        // then
        XCTAssertEqual(sut.refreshInterval, 900)
        XCTAssertEqual(sut.substackFeeds.count, 2) // defaults
    }

    func test_givenNewInterval_whenSet_thenPersistsAndRestartsScheduler() {
        // given
        let sut = makeSUT()

        // when
        sut.refreshInterval = 3_600

        // then
        XCTAssertEqual(preferences.refreshInterval, 3_600)
        XCTAssertEqual(scheduler.startedInterval, 3_600)
    }

    func test_givenValidURL_whenAddingSubstackFeed_thenAddsAndPersists() {
        // given
        let sut = makeSUT()

        // when
        let added = sut.addSubstackFeed(urlString: "myletter.substack.com", category: .technology)

        // then
        XCTAssertTrue(added)
        XCTAssertEqual(sut.substackFeeds.count, 3)
        XCTAssertEqual(
            sut.substackFeeds.last?.url.absoluteString,
            "https://myletter.substack.com/feed"
        )
        XCTAssertEqual(preferences.substackFeeds.count, 3) // persisted
    }

    func test_givenInvalidURL_whenAddingSubstackFeed_thenReturnsFalse() {
        // given
        let sut = makeSUT()
        let invalid = ["", "not a url"]

        // when
        let added = invalid.map { sut.addSubstackFeed(urlString: $0, category: .work) }

        // then
        XCTAssertEqual(added, [false, false])
        XCTAssertEqual(sut.substackFeeds.count, 2)
    }

    func test_givenDuplicateURL_whenAddingSubstackFeed_thenReturnsFalse() {
        // given
        let sut = makeSUT()
        let alreadyFollowed = "https://www.lennysnewsletter.com/feed"

        // when
        let added = sut.addSubstackFeed(urlString: alreadyFollowed, category: .work)

        // then
        XCTAssertFalse(added)
        XCTAssertEqual(sut.substackFeeds.count, 2)
    }

    func test_givenExistingFeed_whenRemoving_thenRemovesAndPersists() {
        // given
        let sut = makeSUT()

        // when
        sut.removeSubstackFeed(at: IndexSet(integer: 0))

        // then
        XCTAssertEqual(sut.substackFeeds.count, 1)
        XCTAssertEqual(preferences.substackFeeds.count, 1)
    }

    func test_givenStoredMaxArticles_whenInitializing_thenLoadsFromPreferences() {
        // given
        preferences.maxArticles = 50

        // when
        let sut = makeSUT()

        // then
        XCTAssertEqual(sut.maxArticles, 50)
    }

    func test_givenChangingMaxArticles_whenSet_thenPersistsAndPreservesCache() {
        // given
        let sut = makeSUT()

        // when
        sut.maxArticles = 30

        // then
        XCTAssertEqual(preferences.maxArticles, 30)
        XCTAssertEqual(cacheRepo.clearAllCallCount, 0, "cached categories must survive a limit change")
    }
}
