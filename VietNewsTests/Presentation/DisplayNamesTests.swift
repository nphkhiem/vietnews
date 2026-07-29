import XCTest
@testable import VietNews

/// These assertions used to live with the domain model tests, which is where the copy itself
/// used to live. Both have moved to the presentation layer.
final class DisplayNamesTests: XCTestCase {
    func test_givenCategory_whenDisplayNameRequested_thenReturnsTheLocalizedName() {
        // given
        let cases: [(NewsCategory, Language, String)] = [
            (.sport, .english, "Sport"),
            (.sport, .vietnamese, "Thể thao"),
            (.hotNews, .vietnamese, "Tin nóng")
        ]

        // when
        let names = cases.map { $0.0.displayName(in: $0.1) }

        // then
        XCTAssertEqual(names, cases.map(\.2))
    }

    /// Every category needs a name in every language, and a missing one would surface as a raw
    /// case name in the category strip.
    func test_givenEveryCategory_whenDisplayNameRequested_thenNeverFallsBackToTheRawValue() {
        // given
        let pairs = NewsCategory.allCases.flatMap { category in
            Language.allCases.map { (category: category, language: $0) }
        }

        // when
        let named = pairs.map { ($0.category, $0.language, $0.category.displayName(in: $0.language)) }

        // then
        for (category, language, name) in named {
            XCTAssertFalse(name.isEmpty)
            XCTAssertNotEqual(name, category.rawValue, "missing \(language.rawValue) name for \(category)")
        }
    }

    /// Publication names are proper nouns and deliberately identical across languages.
    func test_givenSource_whenDisplayNameRequested_thenReadsTheSameInBothLanguages() {
        // given
        let sources = NewsSource.allCases

        // when
        let names = sources.map(\.displayName)

        // then
        XCTAssertEqual(NewsSource.bbc.displayName, "BBC News")
        XCTAssertEqual(NewsSource.vnexpress.displayName, "VNExpress")
        XCTAssertFalse(names.contains(where: \.isEmpty))
    }
}
