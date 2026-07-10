import XCTest
@testable import VietNews

final class DomainModelTests: XCTestCase {
    func test_givenArticleInit_whenCreated_thenIdEqualsURLAbsoluteString() {
        let url = URL(string: "https://vnexpress.net/bong-da-123.html")!
        let article = Article(
            title: "Title", summary: "Summary", url: url, imageURL: nil,
            source: .vnexpress, category: .sport, publishedAt: Date(timeIntervalSince1970: 0)
        )
        XCTAssertEqual(article.id, "https://vnexpress.net/bong-da-123.html")
    }

    func test_givenArticle_whenEncodedAndDecoded_thenRoundTripsEqual() throws {
        let article = Article(
            title: "T", summary: "S", url: URL(string: "https://a.b/c")!,
            imageURL: URL(string: "https://a.b/img.jpg"),
            source: .reddit, category: .game, publishedAt: Date(timeIntervalSince1970: 1_000)
        )
        let data = try JSONEncoder().encode(article)
        let decoded = try JSONDecoder().decode(Article.self, from: data)
        XCTAssertEqual(decoded, article)
    }

    func test_givenNewsCategory_whenCheckingAllCases_thenHasNineCases() {
        XCTAssertEqual(NewsCategory.allCases.count, 9)
    }

    func test_givenCategory_whenDisplayNameRequested_thenReturnsLocalizedName() {
        XCTAssertEqual(NewsCategory.sport.displayName(in: .english), "Sport")
        XCTAssertEqual(NewsCategory.sport.displayName(in: .vietnamese), "Thể thao")
        XCTAssertEqual(NewsCategory.hotNews.displayName(in: .vietnamese), "Tin nóng")
    }

    func test_givenLanguage_whenCheckingRawValue_thenMatchesLocaleCode() {
        XCTAssertEqual(Language.vietnamese.rawValue, "vi")
        XCTAssertEqual(Language.english.rawValue, "en")
    }
}
