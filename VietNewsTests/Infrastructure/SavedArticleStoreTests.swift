import XCTest
@testable import VietNews

@MainActor
final class SavedArticleStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suiteName = "SavedArticleStoreTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func article(_ path: String) -> Article {
        TestFactory.article(url: "https://example.com/\(path)", title: "Story \(path)")
    }

    func test_givenNothingSaved_whenAsked_thenTheListIsEmpty() {
        // given
        let sut = SavedArticleStore(defaults: defaults)

        // when
        let articles = sut.articles

        // then
        XCTAssertTrue(articles.isEmpty)
    }

    func test_givenSeveralSaved_whenListed_thenTheNewestSaveComesFirst() {
        // given
        let sut = SavedArticleStore(defaults: defaults)
        sut.toggle(article("a"))

        // when
        sut.toggle(article("b"))

        // then
        XCTAssertEqual(sut.articles.map(\.id), [article("b").id, article("a").id])
    }

    func test_givenASavedArticle_whenToggledAgain_thenItIsRemoved() {
        // given
        let sut = SavedArticleStore(defaults: defaults)
        sut.toggle(article("a"))

        // when
        let stillSaved = sut.toggle(article("a"))

        // then
        XCTAssertFalse(stillSaved)
        XCTAssertTrue(sut.articles.isEmpty)
        XCTAssertFalse(sut.isSaved(article("a").id))
    }

    /// The whole article is kept, not a reference to one, which is what lets the saved list read
    /// with no connection.
    func test_givenAnArticleIsSaved_whenTheStoreIsRebuilt_thenItsContentIsStillThere() {
        // given
        let sut = SavedArticleStore(defaults: defaults)
        sut.toggle(article("a"))

        // when
        let relaunched = SavedArticleStore(defaults: defaults)

        // then
        XCTAssertEqual(relaunched.articles.count, 1)
        XCTAssertEqual(relaunched.articles.first?.title, "Story a")
        XCTAssertEqual(relaunched.articles.first?.summary, article("a").summary)
        XCTAssertTrue(relaunched.isSaved(article("a").id))
    }

    func test_givenSavedArticles_whenOneIsRemovedByID_thenOnlyItGoes() {
        // given
        let sut = SavedArticleStore(defaults: defaults)
        sut.toggle(article("a"))
        sut.toggle(article("b"))

        // when
        sut.remove(id: article("a").id)

        // then
        XCTAssertEqual(sut.articles.map(\.id), [article("b").id])
    }

    func test_givenAnArticleThatWasNeverSaved_whenRemoved_thenNothingChanges() {
        // given
        let sut = SavedArticleStore(defaults: defaults)
        sut.toggle(article("a"))

        // when
        sut.remove(id: article("z").id)

        // then
        XCTAssertEqual(sut.articles.count, 1)
    }

    /// Saving the same article twice from two places must not put it in the list twice.
    func test_givenTheSameArticleSavedFromTwoPlaces_whenListed_thenItAppearsOnce() {
        // given
        let sut = SavedArticleStore(defaults: defaults)
        sut.toggle(article("a"))
        sut.remove(id: article("a").id)

        // when
        sut.toggle(article("a"))

        // then
        XCTAssertEqual(sut.articles.count, 1)
    }
}
