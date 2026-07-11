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
        XCTAssertEqual(sut.language, .vietnamese)
    }

    func test_givenLanguageSet_whenReadingFromNewInstance_thenPersistsAcrossInstances() {
        sut.language = .english
        XCTAssertEqual(UserPreferences(defaults: defaults).language, .english)
    }

    func test_givenNoStoredInterval_whenReadingRefreshInterval_thenDefaultsTo300() {
        XCTAssertEqual(sut.refreshInterval, 300)
    }

    func test_givenIntervalOutsideRange_whenSetting_thenClampsTo300To600() {
        sut.refreshInterval = 100
        XCTAssertEqual(sut.refreshInterval, 300)
        sut.refreshInterval = 10_000
        XCTAssertEqual(sut.refreshInterval, 600)
        sut.refreshInterval = 450
        XCTAssertEqual(sut.refreshInterval, 450)
    }

    func test_givenNoStoredFeeds_whenReadingSubstackFeeds_thenReturnsDefaultFeeds() {
        let feeds = sut.substackFeeds
        XCTAssertEqual(feeds.count, 2)
        XCTAssertEqual(feeds[0].url.absoluteString, "https://www.lennysnewsletter.com/feed")
        XCTAssertEqual(feeds[0].category, .work)
        XCTAssertEqual(feeds[1].url.absoluteString, "https://newsletter.pragmaticengineer.com/feed")
        XCTAssertEqual(feeds[1].category, .technology)
    }

    func test_givenCustomFeedsSet_whenReadingFromNewInstance_thenPersistsAcrossInstances() {
        let custom = [SubstackFeed(url: URL(string: "https://x.substack.com/feed")!, category: .technology)]
        sut.substackFeeds = custom
        XCTAssertEqual(UserPreferences(defaults: defaults).substackFeeds, custom)
    }
}
