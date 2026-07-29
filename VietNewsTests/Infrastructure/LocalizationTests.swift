import XCTest
@testable import VietNews

final class LocalizationTests: XCTestCase {
    /// The strongest guard in this suite. A missing translation, a typo in a key, or an `.lproj`
    /// folder that failed to make it into the bundle all show up as a string equal to its own
    /// key, and this catches every one of them across both languages at once.
    func test_givenEveryKey_whenResolving_thenNoLanguageFallsBackToTheKey() {
        // given
        let pairs = L10n.allCases.flatMap { key in Language.allCases.map { (key, $0) } }

        // when
        let resolutions = pairs.map { ($0.0, $0.1, $0.0($0.1)) }

        // then
        for (key, language, resolved) in resolutions {
                XCTAssertNotEqual(
                    resolved,
                    key.rawValue,
                    "missing \(language.rawValue) translation for \(key.rawValue)"
                )
                XCTAssertFalse(
                    resolved.isEmpty,
                    "empty \(language.rawValue) translation for \(key.rawValue)"
                )
        }
    }

    /// Two languages resolving to the same text usually means one bundle is not being used.
    func test_givenTranslatableKeys_whenComparingLanguages_thenTheyActuallyDiffer() {
        // given
        // The nameplate is a proper noun, the settings words happen to be shared, and the feed
        // address placeholder is an example URL rather than prose.
        let sameInBothLanguages: Set<L10n> = [
            .appName, .settingsTitle, .settingsSectionLanguage, .subscribePlaceholder
        ]
        let translatable = L10n.allCases.filter { !sameInBothLanguages.contains($0) }

        // when
        let resolutions = translatable.map { ($0, $0(.vietnamese), $0(.english)) }

        // then
        for (key, vietnamese, english) in resolutions {
            XCTAssertNotEqual(
                vietnamese,
                english,
                "\(key.rawValue) is identical in both languages, which suggests the wrong bundle"
            )
        }
    }

    func test_givenKnownKeys_whenResolving_thenReturnsTheExpectedText() {
        // given
        let cases: [(L10n, Language, String)] = [
            (.tabFeed, .english, "Feed"),
            (.tabFeed, .vietnamese, "Tin tức"),
            (.categoryHotNews, .vietnamese, "Tin nóng"),
            (.feedRetry, .vietnamese, "Thử lại")
        ]

        // when
        let resolved = cases.map { $0.0($0.1) }

        // then
        XCTAssertEqual(resolved, cases.map(\.2))
    }

    /// The whole point of the resolver: the reader's choice beats the device's locale.
    func test_givenLanguageChoice_whenResolving_thenIgnoresTheSystemLocale() {
        // given
        let key = L10n.settingsAdd

        // when
        let resolved = Language.allCases.map { key($0) }

        // then
        XCTAssertEqual(resolved, ["Thêm", "Add"])
    }

    func test_givenSubstitutedValue_whenResolving_thenInsertsIt() {
        // given
        let key = L10n.feedLastUpdated

        // when
        let english = key(.english, "2 hours ago")
        let vietnamese = key(.vietnamese, "2 giờ trước")

        // then
        XCTAssertEqual(english, "Last updated 2 hours ago")
        XCTAssertTrue(vietnamese.contains("2 giờ trước"))
    }

    func test_givenEnglishCounts_whenResolvingPlurals_thenInflects() {
        // given
        let cases: [(L10nPlural, Int, String)] = [
            (.minutesAgo, 1, "1 minute ago"),
            (.minutesAgo, 5, "5 minutes ago"),
            (.hoursAgo, 1, "1 hour ago"),
            (.daysAgo, 3, "3 days ago"),
            (.settingsInterval, 5, "Every 5 minutes")
        ]

        // when
        let resolved = cases.map { $0.0(.english, count: $0.1) }

        // then
        XCTAssertEqual(resolved, cases.map(\.2))
    }

    /// Vietnamese does not inflect for number, so one and many take the same form. Declaring it
    /// in the dictionary keeps that fact in the language rather than in a Swift conditional.
    func test_givenVietnameseCounts_whenResolvingPlurals_thenUsesOneForm() {
        // given
        let cases: [(L10nPlural, Int, String)] = [
            (.minutesAgo, 1, "1 phút trước"),
            (.minutesAgo, 5, "5 phút trước"),
            (.daysAgo, 3, "3 ngày trước"),
            (.settingsInterval, 10, "Mỗi 10 phút")
        ]

        // when
        let resolved = cases.map { $0.0(.vietnamese, count: $0.1) }

        // then
        XCTAssertEqual(resolved, cases.map(\.2))
    }

    func test_givenLanguage_whenDerivingLocale_thenMatchesThatLanguage() {
        // given
        let languages = Language.allCases

        // when
        let identifiers = languages.map(\.locale.identifier)

        // then
        XCTAssertEqual(identifiers, ["vi_VN", "en_US"])
    }
}
