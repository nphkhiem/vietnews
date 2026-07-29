import XCTest
@testable import VietNews

final class ReadArticleStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "ReadArticleStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_givenNothingRead_whenAsked_thenTheSetIsEmpty() {
        // given
        let sut = ReadArticleStore(defaults: defaults)

        // when
        let readIDs = sut.readIDs

        // then
        XCTAssertTrue(readIDs.isEmpty)
    }

    /// The point of the ticket: a refreshed feed must not present the same headlines as new.
    func test_givenArticlesRead_whenTheStoreIsRebuilt_thenTheyAreStillRead() {
        // given
        let first = ReadArticleStore(defaults: defaults)
        first.markRead("https://example.com/a")
        first.markRead("https://example.com/b")

        // when
        let relaunched = ReadArticleStore(defaults: defaults)

        // then
        XCTAssertEqual(relaunched.readIDs, ["https://example.com/a", "https://example.com/b"])
    }

    func test_givenTheSameArticleReadTwice_whenAsked_thenItIsHeldOnce() {
        // given
        let sut = ReadArticleStore(defaults: defaults)
        sut.markRead("a")

        // when
        sut.markRead("a")

        // then
        XCTAssertEqual(sut.readIDs, ["a"])
    }

    func test_givenMoreArticlesThanTheLimit_whenRead_thenTheOldestAreDropped() {
        // given
        let sut = ReadArticleStore(defaults: defaults, limit: 3)

        // when
        for id in ["a", "b", "c", "d"] { sut.markRead(id) }

        // then
        XCTAssertEqual(sut.readIDs, ["b", "c", "d"])
    }

    /// Something the reader keeps returning to should not be the first thing forgotten.
    func test_givenAnOldArticleIsReadAgain_whenTheLimitIsReached_thenItSurvives() {
        // given
        let sut = ReadArticleStore(defaults: defaults, limit: 3)
        for id in ["a", "b", "c"] { sut.markRead(id) }
        sut.markRead("a")

        // when
        sut.markRead("d")

        // then
        XCTAssertEqual(sut.readIDs, ["c", "a", "d"])
    }

    func test_givenAStoredListLongerThanTheLimit_whenLoaded_thenItIsTrimmedToTheNewest() {
        // given
        defaults.set(["a", "b", "c", "d", "e"], forKey: "reader.readArticleIDs")

        // when
        let sut = ReadArticleStore(defaults: defaults, limit: 2)

        // then
        XCTAssertEqual(sut.readIDs, ["d", "e"])
    }

    /// The cap has to clear the largest feed the app can build, or an article could be forgotten
    /// while it is still on screen.
    func test_givenTheDefaultLimit_whenComparedToTheLargestPossibleFeed_thenItClearsIt() {
        // given
        let largestFeed = 70 * NewsCategory.allCases.count

        // when
        let limit = ReadArticleStore.defaultLimit

        // then
        XCTAssertGreaterThan(limit, largestFeed)
    }
}
