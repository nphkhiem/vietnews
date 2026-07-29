import XCTest
@testable import VietNews

/// Serves whatever a test puts in it, per category, without touching the disk.
private final class InMemoryCache: CacheRepository {
    var entries: [NewsCategory: [Article]] = [:]
    private(set) var loadCount = 0

    func save(_ entry: CachedArticles, category: NewsCategory, language: Language) throws {}
    func clearAll() throws {}
    func totalSizeInBytes() -> Int { 0 }

    func load(category: NewsCategory, language: Language) -> CachedArticles? {
        loadCount += 1
        guard let articles = entries[category] else { return nil }
        return CachedArticles(articles: articles, fetchedAt: Date(timeIntervalSince1970: 1))
    }
}

@MainActor
final class SearchViewModelTests: XCTestCase {
    private var cache: InMemoryCache!

    override func setUp() {
        super.setUp()
        cache = InMemoryCache()
    }

    private func article(_ title: String, summary: String = "Summary", at epoch: TimeInterval = 1) -> Article {
        Article(
            title: title,
            summary: summary,
            url: URL(string: "https://example.com/\(abs(title.hashValue))")!,
            imageURL: nil,
            source: .vnexpress,
            category: .hotNews,
            publishedAt: Date(timeIntervalSince1970: epoch)
        )
    }

    private func makeSUT(language: Language = .vietnamese) -> SearchViewModel {
        SearchViewModel(cache: cache, language: language)
    }

    func test_givenNoQuery_whenLoaded_thenNothingIsListed() {
        cache.entries[.hotNews] = [article("Một tin")]
        let sut = makeSUT()

        sut.load()

        // A list of everything cached is not a search result, and the feed already does that.
        XCTAssertTrue(sut.results.isEmpty)
    }

    func test_givenAQuery_whenMatchingAHeadline_thenTheArticleIsListed() {
        cache.entries[.hotNews] = [article("Chelsea thắng derby"), article("Giá vàng tăng")]
        let sut = makeSUT()
        sut.load()

        sut.query = "derby"

        XCTAssertEqual(sut.results.map(\.title), ["Chelsea thắng derby"])
    }

    func test_givenAQuery_whenMatchingASummary_thenTheArticleIsListed() {
        cache.entries[.hotNews] = [article("Headline", summary: "A quiet day in Hanoi")]
        let sut = makeSUT()
        sut.load()

        sut.query = "hanoi"

        XCTAssertEqual(sut.results.count, 1)
    }

    /// Not a nicety in Vietnamese. Typing the tone marks correctly on a phone keyboard is exactly
    /// the work search is meant to save the reader.
    func test_givenAQueryWithoutDiacritics_whenSearching_thenItStillMatches() {
        cache.entries[.hotNews] = [article("Thể thao trong nước")]
        let sut = makeSUT()
        sut.load()

        sut.query = "the thao"

        XCTAssertEqual(sut.results.count, 1)
    }

    func test_givenADifferentCase_whenSearching_thenItStillMatches() {
        cache.entries[.hotNews] = [article("Chelsea thắng derby")]
        let sut = makeSUT()
        sut.load()

        sut.query = "CHELSEA"

        XCTAssertEqual(sut.results.count, 1)
    }

    func test_givenSeveralCategories_whenSearching_thenResultsCrossThemAll() {
        cache.entries[.hotNews] = [article("Tin nóng về giá vàng")]
        cache.entries[.finance] = [article("Giá vàng hôm nay")]
        let sut = makeSUT()
        sut.load()

        sut.query = "giá vàng"

        XCTAssertEqual(sut.results.count, 2)
    }

    /// The same article is cached under more than one category, and a reader searching does not
    /// want to be shown it twice.
    func test_givenTheSameArticleInTwoCategories_whenSearching_thenItAppearsOnce() {
        let shared = article("Giá vàng hôm nay")
        cache.entries[.hotNews] = [shared]
        cache.entries[.finance] = [shared]
        let sut = makeSUT()
        sut.load()

        sut.query = "vàng"

        XCTAssertEqual(sut.results.count, 1)
    }

    func test_givenNothingMatches_whenSearching_thenTheResultIsEmptyRatherThanAnError() {
        cache.entries[.hotNews] = [article("Chelsea thắng derby")]
        let sut = makeSUT()
        sut.load()

        sut.query = "nothing here"

        XCTAssertTrue(sut.results.isEmpty)
        XCTAssertFalse(sut.corpus.isEmpty, "the corpus loaded; there simply was no match")
    }

    /// Re-reading every category file on each character typed would make typing the slow part.
    func test_givenTheCorpusIsLoaded_whenTypingSeveralCharacters_thenTheCacheIsNotReadAgain() {
        cache.entries[.hotNews] = [article("Chelsea thắng derby")]
        let sut = makeSUT()
        sut.load()
        let readsAfterLoad = cache.loadCount

        sut.query = "c"
        sut.query = "ch"
        sut.query = "che"

        XCTAssertEqual(cache.loadCount, readsAfterLoad)
    }

    func test_givenResults_whenListed_thenTheyAreNewestFirst() {
        cache.entries[.hotNews] = [
            article("Older gold", at: 10),
            article("Newer gold", at: 20)
        ]
        let sut = makeSUT()
        sut.load()

        sut.query = "gold"

        XCTAssertEqual(sut.results.map(\.title), ["Newer gold", "Older gold"])
    }
}

final class SearchRangeTests: XCTestCase {
    func test_givenATermAppearingTwice_whenFindingRanges_thenBothAreReported() {
        let text = "Gold and more gold"

        XCTAssertEqual(text.searchRanges(of: "gold").count, 2)
    }

    /// Ranges come back in the original string, which is what makes highlighting a diacritic
    /// insensitive match possible without mapping indices from a folded copy.
    func test_givenADiacriticInsensitiveMatch_whenFindingRanges_thenTheyIndexTheOriginal() {
        let text = "Thể thao"

        let ranges = text.searchRanges(of: "the")

        XCTAssertEqual(ranges.count, 1)
        XCTAssertEqual(String(text[ranges[0]]), "Thể")
    }

    func test_givenAnEmptyTerm_whenFindingRanges_thenItReturnsNothingRatherThanLooping() {
        XCTAssertTrue("anything".searchRanges(of: "").isEmpty)
    }
}
