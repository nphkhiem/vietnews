import XCTest
@testable import VietNews

@MainActor
final class SourcesViewModelTests: XCTestCase {
    private var health: MockSourceHealthRepository!
    private var preferences: UserPreferences!
    private var defaults: UserDefaults!
    private let suiteName = "SourcesViewModelTests"
    private let feedURL = URL(string: "https://newsletter.pragmaticengineer.com/feed")!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        preferences = UserPreferences(defaults: defaults)
        health = MockSourceHealthRepository()
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeSUT(language: Language = .english) -> SourcesViewModel {
        SourcesViewModel(
            health: health,
            preferences: preferences,
            language: language,
            serves: { _, _ in true }
        )
    }

    func test_givenNoFailures_whenListing_thenEverySourceAppearsExactlyOnce() {
        let sut = makeSUT()

        let listed = sut.failing + sut.builtIn + sut.userFeeds
        XCTAssertEqual(sut.failing.count, 0)
        XCTAssertEqual(sut.builtIn.count, NewsSource.allCases.count)
        XCTAssertEqual(sut.userFeeds.count, preferences.substackFeeds.count)
        XCTAssertEqual(Set(listed.map(\.id)).count, listed.count)
    }

    /// A broken source is the reason anyone opens this screen, so it is lifted out of its group
    /// rather than merely sorted within it.
    func test_givenAFailingSource_whenListing_thenItLeavesItsGroupForTheTop() {
        health.recordFailure(.builtIn(.bbc), cause: .rejected)
        let sut = makeSUT()

        XCTAssertEqual(sut.failing.map(\.identity), [.builtIn(.bbc)])
        XCTAssertFalse(sut.builtIn.contains { $0.identity == .builtIn(.bbc) })
    }

    func test_givenAFailingUserFeed_whenListing_thenItAlsoReachesTheTop() {
        preferences.substackFeeds = [SubstackFeed(url: feedURL, category: .technology)]
        health.recordFailure(.userFeed(feedURL), cause: .unreachable)
        let sut = makeSUT()

        XCTAssertEqual(sut.failing.map(\.identity), [.userFeed(feedURL)])
        XCTAssertTrue(sut.userFeeds.isEmpty)
    }

    func test_givenAFeedThatNamedItself_whenListed_thenItUsesThatNameNotItsHost() {
        preferences.substackFeeds = [SubstackFeed(url: feedURL, category: .technology)]
        health.recordSuccess(.userFeed(feedURL), at: Date(), publicationTitle: "The Pragmatic Engineer")

        XCTAssertEqual(makeSUT().userFeeds.first?.name, "The Pragmatic Engineer")
    }

    func test_givenAFeedNeverRead_whenListed_thenItFallsBackToItsHost() {
        preferences.substackFeeds = [SubstackFeed(url: feedURL, category: .technology)]

        XCTAssertEqual(makeSUT().userFeeds.first?.name, "newsletter.pragmaticengineer.com")
    }

    func test_givenASourceIsSwitchedOff_whenReloaded_thenTheListingReportsItOff() {
        let sut = makeSUT()

        sut.setEnabled(false, for: .builtIn(.eurogamer))

        let listing = sut.builtIn.first { $0.identity == .builtIn(.eurogamer) }
        XCTAssertEqual(listing?.isEnabled, false)
        XCTAssertFalse(health.isEnabled(.builtIn(.eurogamer)))
    }

    /// A source that serves nothing in the reader's language says so, rather than reporting a
    /// coverage the feed will never show them.
    func test_givenASourceServingNothingInThisLanguage_whenListed_thenItSaysSo() {
        let sut = SourcesViewModel(
            health: health,
            preferences: preferences,
            language: .english,
            serves: { _, _ in false }
        )

        let listing = sut.builtIn.first { $0.identity == .builtIn(.bbc) }
        XCTAssertEqual(listing?.scope, L10n.sourcesNotInLanguage(.english))
    }
}
