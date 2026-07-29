import XCTest
@testable import VietNews

final class UserPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: UserPreferences!
    private let suiteName = "UserPreferencesTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        sut = UserPreferences(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_givenNoStoredLanguage_whenReadingLanguage_thenDefaultsToVietnamese() {
        // given
        // Nothing stored: `setUp` wipes the suite before every test.

        // when
        let language = sut.language

        // then
        XCTAssertEqual(language, .vietnamese)
    }

    func test_givenLanguageSet_whenReadingFromNewInstance_thenPersistsAcrossInstances() {
        // given
        sut.language = .english

        // when
        let reloaded = UserPreferences(defaults: defaults).language

        // then
        XCTAssertEqual(reloaded, .english)
    }

    func test_givenNoStoredInterval_whenReadingRefreshInterval_thenDefaultsTo300() {
        // given
        // Nothing stored, which is distinct from a stored zero meaning the reader turned it off.

        // when
        let interval = sut.refreshInterval

        // then
        XCTAssertEqual(interval, 300)
    }

    /// The interval is a choice from a list now rather than a point on a range, so an
    /// unrecognised value snaps to the default instead of being clamped into a band. Ticket 34
    /// replaced the five to ten minute slider, which offered no real choice and could not be
    /// switched off.
    func test_givenAnIntervalNotOffered_whenSetting_thenItSnapsToTheDefault() {
        // given
        let notOffered: [TimeInterval] = [100, 10_000]

        // when
        let stored = notOffered.map { value -> TimeInterval in
            sut.refreshInterval = value
            return sut.refreshInterval
        }

        // then
        XCTAssertEqual(stored, [300, 300])
    }

    func test_givenAnOfferedInterval_whenSetting_thenItIsKept() {
        // given
        let offered: TimeInterval = 1_800

        // when
        sut.refreshInterval = offered

        // then
        XCTAssertEqual(sut.refreshInterval, offered)
    }

    func test_givenNoStoredFeeds_whenReadingSubstackFeeds_thenReturnsDefaultFeeds() {
        // given
        // Nothing stored, so the shipped defaults stand in.

        // when
        let feeds = sut.substackFeeds

        // then
        XCTAssertEqual(feeds.count, 2)
        XCTAssertEqual(feeds[0].url.absoluteString, "https://www.lennysnewsletter.com/feed")
        XCTAssertEqual(feeds[0].category, .work)
        XCTAssertEqual(feeds[1].url.absoluteString, "https://newsletter.pragmaticengineer.com/feed")
        XCTAssertEqual(feeds[1].category, .technology)
    }

    func test_givenCustomFeedsSet_whenReadingFromNewInstance_thenPersistsAcrossInstances() {
        // given
        let custom = [SubstackFeed(url: URL(string: "https://x.substack.com/feed")!, category: .technology)]
        sut.substackFeeds = custom

        // when
        let reloaded = UserPreferences(defaults: defaults).substackFeeds

        // then
        XCTAssertEqual(reloaded, custom)
    }

    func test_givenNoStoredMaxArticles_whenReadingMaxArticles_thenDefaultsTo15() {
        // given
        // Nothing stored.

        // when
        let maxArticles = sut.maxArticles

        // then
        XCTAssertEqual(maxArticles, 15)
    }

    func test_givenValidMaxArticlesSet_whenReadingFromNewInstance_thenPersistsAcrossInstances() {
        // given
        sut.maxArticles = 50

        // when
        let reloaded = UserPreferences(defaults: defaults).maxArticles

        // then
        XCTAssertEqual(reloaded, 50)
    }

    func test_givenInvalidMaxArticlesValue_whenSetting_thenSnapsTo15() {
        // given
        let notOffered = 22

        // when
        sut.maxArticles = notOffered

        // then
        XCTAssertEqual(sut.maxArticles, 15)
    }
}
