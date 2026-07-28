import XCTest
@testable import VietNews

final class LocalizationTests: XCTestCase {
    /// The strongest guard in this suite. A missing translation, a typo in a key, or an `.lproj`
    /// folder that failed to make it into the bundle all show up as a string equal to its own
    /// key, and this catches every one of them across both languages at once.
    func test_givenEveryKey_whenResolving_thenNoLanguageFallsBackToTheKey() {
        for key in L10n.allCases {
            for language in Language.allCases {
                let resolved = key(language)
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
    }

    /// Two languages resolving to the same text usually means one bundle is not being used.
    func test_givenTranslatableKeys_whenComparingLanguages_thenTheyActuallyDiffer() {
        let sameInBothLanguages: Set<L10n> = [.settingsTitle, .settingsSectionLanguage]

        for key in L10n.allCases where !sameInBothLanguages.contains(key) {
            XCTAssertNotEqual(
                key(.vietnamese),
                key(.english),
                "\(key.rawValue) is identical in both languages, which suggests the wrong bundle"
            )
        }
    }

    func test_givenKnownKeys_whenResolving_thenReturnsTheExpectedText() {
        XCTAssertEqual(L10n.tabFeed(.english), "Feed")
        XCTAssertEqual(L10n.tabFeed(.vietnamese), "Tin tức")
        XCTAssertEqual(L10n.categoryHotNews(.vietnamese), "Tin nóng")
        XCTAssertEqual(L10n.feedRetry(.vietnamese), "Thử lại")
    }

    /// The whole point of the resolver: the reader's choice beats the device's locale.
    func test_givenLanguageChoice_whenResolving_thenIgnoresTheSystemLocale() {
        XCTAssertEqual(L10n.settingsAdd(.vietnamese), "Thêm")
        XCTAssertEqual(L10n.settingsAdd(.english), "Add")
    }

    func test_givenSubstitutedValue_whenResolving_thenInsertsIt() {
        XCTAssertEqual(L10n.feedLastUpdated(.english, "2 hours ago"), "Last updated 2 hours ago")
        XCTAssertTrue(L10n.feedLastUpdated(.vietnamese, "2 giờ trước").contains("2 giờ trước"))
    }

    func test_givenEnglishCounts_whenResolvingPlurals_thenInflects() {
        XCTAssertEqual(L10nPlural.minutesAgo(.english, count: 1), "1 minute ago")
        XCTAssertEqual(L10nPlural.minutesAgo(.english, count: 5), "5 minutes ago")
        XCTAssertEqual(L10nPlural.hoursAgo(.english, count: 1), "1 hour ago")
        XCTAssertEqual(L10nPlural.daysAgo(.english, count: 3), "3 days ago")
        XCTAssertEqual(L10nPlural.settingsInterval(.english, count: 5), "Every 5 minutes")
    }

    /// Vietnamese does not inflect for number, so one and many take the same form. Declaring it
    /// in the dictionary keeps that fact in the language rather than in a Swift conditional.
    func test_givenVietnameseCounts_whenResolvingPlurals_thenUsesOneForm() {
        XCTAssertEqual(L10nPlural.minutesAgo(.vietnamese, count: 1), "1 phút trước")
        XCTAssertEqual(L10nPlural.minutesAgo(.vietnamese, count: 5), "5 phút trước")
        XCTAssertEqual(L10nPlural.daysAgo(.vietnamese, count: 3), "3 ngày trước")
        XCTAssertEqual(L10nPlural.settingsInterval(.vietnamese, count: 10), "Mỗi 10 phút")
    }

    func test_givenLanguage_whenDerivingLocale_thenMatchesThatLanguage() {
        XCTAssertEqual(Language.vietnamese.locale.identifier, "vi_VN")
        XCTAssertEqual(Language.english.locale.identifier, "en_US")
    }
}
