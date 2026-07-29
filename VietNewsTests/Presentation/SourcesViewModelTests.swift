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
        // given
        let sut = makeSUT()

        // when
        let listed = sut.failing + sut.builtIn + sut.userFeeds

        // then
        XCTAssertEqual(sut.failing.count, 0)
        XCTAssertEqual(sut.builtIn.count, NewsSource.allCases.count)
        XCTAssertEqual(sut.userFeeds.count, preferences.substackFeeds.count)
        XCTAssertEqual(Set(listed.map(\.id)).count, listed.count)
    }

    /// A broken source is the reason anyone opens this screen, so it is lifted out of its group
    /// rather than merely sorted within it.
    func test_givenAFailingSource_whenListing_thenItLeavesItsGroupForTheTop() {
        // given
        health.recordFailure(.builtIn(.bbc), cause: .rejected)

        // when
        let sut = makeSUT()

        // then
        XCTAssertEqual(sut.failing.map(\.identity), [.builtIn(.bbc)])
        XCTAssertFalse(sut.builtIn.contains { $0.identity == .builtIn(.bbc) })
    }

    func test_givenAFailingUserFeed_whenListing_thenItAlsoReachesTheTop() {
        // given
        preferences.substackFeeds = [SubstackFeed(url: feedURL, category: .technology)]
        health.recordFailure(.userFeed(feedURL), cause: .unreachable)

        // when
        let sut = makeSUT()

        // then
        XCTAssertEqual(sut.failing.map(\.identity), [.userFeed(feedURL)])
        XCTAssertTrue(sut.userFeeds.isEmpty)
    }

    func test_givenAFeedThatNamedItself_whenListed_thenItUsesThatNameNotItsHost() {
        // given
        preferences.substackFeeds = [SubstackFeed(url: feedURL, category: .technology)]
        health.recordSuccess(.userFeed(feedURL), at: Date(), publicationTitle: "The Pragmatic Engineer")

        // when
        let listing = makeSUT().userFeeds.first

        // then
        XCTAssertEqual(listing?.name, "The Pragmatic Engineer")
    }

    func test_givenAFeedNeverRead_whenListed_thenItFallsBackToItsHost() {
        // given
        preferences.substackFeeds = [SubstackFeed(url: feedURL, category: .technology)]

        // when
        let listing = makeSUT().userFeeds.first

        // then
        XCTAssertEqual(listing?.name, "newsletter.pragmaticengineer.com")
    }

    func test_givenASourceIsSwitchedOff_whenReloaded_thenTheListingReportsItOff() {
        // given
        let sut = makeSUT()
        sut.setEnabled(false, for: .builtIn(.eurogamer))

        // when
        let listing = sut.builtIn.first { $0.identity == .builtIn(.eurogamer) }

        // then
        XCTAssertEqual(listing?.isEnabled, false)
        XCTAssertFalse(health.isEnabled(.builtIn(.eurogamer)))
    }

    /// A source that serves nothing in the reader's language says so, rather than reporting a
    /// coverage the feed will never show them.
    func test_givenASourceServingNothingInThisLanguage_whenListed_thenItSaysSo() {
        // given
        let sut = SourcesViewModel(
            health: health,
            preferences: preferences,
            language: .english,
            serves: { _, _ in false }
        )

        // when
        let listing = sut.builtIn.first { $0.identity == .builtIn(.bbc) }

        // then
        XCTAssertEqual(listing?.scope, L10n.sourcesNotInLanguage(.english))
    }
}
