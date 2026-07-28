import XCTest
@testable import VietNews

/// These assertions used to live with the domain model tests, which is where the copy itself
/// used to live. Both have moved to the presentation layer.
final class DisplayNamesTests: XCTestCase {
    func test_givenCategory_whenDisplayNameRequested_thenReturnsTheLocalizedName() {
        XCTAssertEqual(NewsCategory.sport.displayName(in: .english), "Sport")
        XCTAssertEqual(NewsCategory.sport.displayName(in: .vietnamese), "Thể thao")
        XCTAssertEqual(NewsCategory.hotNews.displayName(in: .vietnamese), "Tin nóng")
    }

    /// Every category needs a name in every language, and a missing one would surface as a raw
    /// case name in the category strip.
    func test_givenEveryCategory_whenDisplayNameRequested_thenNeverFallsBackToTheRawValue() {
        for category in NewsCategory.allCases {
            for language in Language.allCases {
                let name = category.displayName(in: language)
                XCTAssertFalse(name.isEmpty)
                XCTAssertNotEqual(name, category.rawValue, "missing \(language.rawValue) name for \(category)")
            }
        }
    }

    /// Publication names are proper nouns and deliberately identical across languages.
    func test_givenSource_whenDisplayNameRequested_thenReadsTheSameInBothLanguages() {
        XCTAssertEqual(NewsSource.bbc.displayName, "BBC News")
        XCTAssertEqual(NewsSource.vnexpress.displayName, "VNExpress")
        for source in NewsSource.allCases {
            XCTAssertFalse(source.displayName.isEmpty)
        }
    }
}
