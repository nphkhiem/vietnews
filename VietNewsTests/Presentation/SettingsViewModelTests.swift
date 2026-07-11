import XCTest
@testable import VietNews

@MainActor
final class SettingsViewModelTests: XCTestCase {
    private var preferences: UserPreferences!
    private var scheduler: MockRefreshScheduler!
    private var defaults: UserDefaults!
    private let suiteName = "SettingsViewModelTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        preferences = UserPreferences(defaults: defaults)
        scheduler = MockRefreshScheduler()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSUT() -> SettingsViewModel {
        SettingsViewModel(preferences: preferences, scheduler: scheduler)
    }

    func test_givenStoredPreferences_whenInitializing_thenLoadsInitialValues() {
        preferences.refreshInterval = 450
        let sut = makeSUT()
        XCTAssertEqual(sut.refreshInterval, 450)
        XCTAssertEqual(sut.substackFeeds.count, 2) // defaults
    }

    func test_givenNewInterval_whenSet_thenPersistsAndRestartsScheduler() {
        let sut = makeSUT()

        sut.refreshInterval = 600

        XCTAssertEqual(preferences.refreshInterval, 600)
        XCTAssertEqual(scheduler.startedInterval, 600)
    }

    func test_givenValidURL_whenAddingSubstackFeed_thenAddsAndPersists() {
        let sut = makeSUT()

        let added = sut.addSubstackFeed(urlString: "myletter.substack.com", category: .technology)

        XCTAssertTrue(added)
        XCTAssertEqual(sut.substackFeeds.count, 3)
        XCTAssertEqual(
            sut.substackFeeds.last?.url.absoluteString,
            "https://myletter.substack.com/feed"
        )
        XCTAssertEqual(preferences.substackFeeds.count, 3) // persisted
    }

    func test_givenInvalidURL_whenAddingSubstackFeed_thenReturnsFalse() {
        let sut = makeSUT()
        XCTAssertFalse(sut.addSubstackFeed(urlString: "", category: .work))
        XCTAssertFalse(sut.addSubstackFeed(urlString: "not a url", category: .work))
        XCTAssertEqual(sut.substackFeeds.count, 2)
    }

    func test_givenDuplicateURL_whenAddingSubstackFeed_thenReturnsFalse() {
        let sut = makeSUT()
        XCTAssertFalse(
            sut.addSubstackFeed(urlString: "https://www.lennysnewsletter.com/feed", category: .work)
        )
        XCTAssertEqual(sut.substackFeeds.count, 2)
    }

    func test_givenExistingFeed_whenRemoving_thenRemovesAndPersists() {
        let sut = makeSUT()

        sut.removeSubstackFeed(at: IndexSet(integer: 0))

        XCTAssertEqual(sut.substackFeeds.count, 1)
        XCTAssertEqual(preferences.substackFeeds.count, 1)
    }
}
