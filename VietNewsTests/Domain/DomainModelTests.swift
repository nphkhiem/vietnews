import XCTest
@testable import VietNews

final class DomainModelTests: XCTestCase {
    func test_givenArticleInit_whenCreated_thenIdEqualsURLAbsoluteString() {
        // given
        let url = URL(string: "https://vnexpress.net/bong-da-123.html")!

        // when
        let article = Article(
            title: "Title", summary: "Summary", url: url, imageURL: nil,
            source: .vnexpress, category: .sport, publishedAt: Date(timeIntervalSince1970: 0)
        )

        // then
        XCTAssertEqual(article.id, "https://vnexpress.net/bong-da-123.html")
    }

    func test_givenArticle_whenEncodedAndDecoded_thenRoundTripsEqual() throws {
        // given
        let article = Article(
            title: "T", summary: "S", url: URL(string: "https://a.b/c")!,
            imageURL: URL(string: "https://a.b/img.jpg"),
            source: .eurogamer, category: .game, publishedAt: Date(timeIntervalSince1970: 1_000)
        )
        let data = try JSONEncoder().encode(article)

        // when
        let decoded = try JSONDecoder().decode(Article.self, from: data)

        // then
        XCTAssertEqual(decoded, article)
    }

    func test_givenNewsCategory_whenCheckingAllCases_thenHasNineCases() {
        // given
        let categories = NewsCategory.allCases

        // when
        let count = categories.count

        // then
        XCTAssertEqual(count, 9)
    }

    func test_givenNewsCategory_whenCheckingAllCases_thenHotNewsIsFirst() {
        // given
        let categories = NewsCategory.allCases

        // when
        let first = categories.first

        // then
        XCTAssertEqual(first, .hotNews)
    }

    func test_givenLanguage_whenCheckingRawValue_thenMatchesLocaleCode() {
        // given
        let languages = Language.allCases

        // when
        let codes = languages.map(\.rawValue)

        // then
        XCTAssertEqual(codes, ["vi", "en"])
    }

    func test_givenGameCategory_whenCheckingAvailability_thenOnlyAvailableInEnglish() {
        // given
        let category = NewsCategory.game

        // when
        let availability = Language.allCases.map { category.isAvailable(in: $0) }

        // then
        XCTAssertEqual(availability, [false, true], "expected English only")
    }

    func test_givenSocialCategory_whenCheckingAvailability_thenOnlyAvailableInVietnamese() {
        // given
        let category = NewsCategory.social

        // when
        let availability = Language.allCases.map { category.isAvailable(in: $0) }

        // then
        XCTAssertEqual(availability, [true, false], "expected Vietnamese only")
    }

    func test_givenOtherCategories_whenCheckingAvailability_thenAvailableInBothLanguages() {
        // given
        let unrestricted: [NewsCategory] = [.sport, .hotNews, .world, .finance, .work, .technology, .car]

        // when
        let availability = unrestricted.map { c in Language.allCases.map { c.isAvailable(in: $0) } }

        // then
        XCTAssertTrue(availability.allSatisfy { $0.allSatisfy { $0 } })
    }
}
