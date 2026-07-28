import XCTest
@testable import VietNews

final class ArticleTimestampFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func test_givenArticleUnderOneHourOld_whenFormatting_thenShowsMinutesAgoEnglish() {
        let date = now.addingTimeInterval(-30 * 60)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "30 minutes ago")
    }

    func test_givenArticleUnderOneDayOld_whenFormatting_thenShowsHoursAgoEnglish() {
        let date = now.addingTimeInterval(-5 * 3600)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "5 hours ago")
    }

    func test_givenArticleOneHourOldExactly_whenFormatting_thenShowsSingularHourEnglish() {
        let date = now.addingTimeInterval(-1 * 3600)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "1 hour ago")
    }

    func test_givenArticleBetweenOneAndSevenDaysOld_whenFormatting_thenShowsDaysAgoEnglish() {
        let date = now.addingTimeInterval(-3 * 86400)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "3 days ago")
    }


    func test_givenArticleUnderOneDayOld_whenFormatting_thenShowsHoursAgoVietnamese() {
        let date = now.addingTimeInterval(-5 * 3600)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now), "5 giờ trước")
    }

    func test_givenArticleBetweenOneAndSevenDaysOld_whenFormatting_thenShowsDaysAgoVietnamese() {
        let date = now.addingTimeInterval(-3 * 86400)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now), "3 ngày trước")
    }

    func test_givenArticleExactlySevenDaysOld_whenFormatting_thenShowsDaysAgo() {
        let date = now.addingTimeInterval(-7 * 86400)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "7 days ago")
    }

    func test_givenNoDate_whenFormatting_thenShowsNothingRatherThanAFabricatedOne() {
        XCTAssertNil(ArticleTimestampFormatter.string(for: nil, language: .english, now: now))
        XCTAssertNil(ArticleTimestampFormatter.string(for: nil, language: .vietnamese, now: now))
    }

    /// Feeds drift slightly ahead of the device clock, and that is not a broken date.
    func test_givenDateSlightlyInTheFuture_whenFormatting_thenTreatsItAsJustNow() {
        let date = now.addingTimeInterval(30)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "Just now")
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now), "Vừa xong")
    }

    /// The bug this replaces: a date hours in the future rendered as "1 minute ago", claiming an
    /// article had just been published when its date was unusable.
    func test_givenDateFarInTheFuture_whenFormatting_thenShowsNothing() {
        let date = now.addingTimeInterval(6 * 3600)
        XCTAssertNil(ArticleTimestampFormatter.string(for: date, language: .english, now: now))
    }

    func test_givenArticleSecondsOld_whenFormatting_thenShowsJustNow() {
        let date = now.addingTimeInterval(-20)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "Just now")
    }

    func test_givenArticleExactlyOneMinuteOld_whenFormatting_thenShowsSingularMinute() {
        let date = now.addingTimeInterval(-60)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "1 minute ago")
    }

    func test_givenArticleOlderThanAWeek_whenFormatting_thenUsesTheReadersOwnDateConventions() {
        let date = now.addingTimeInterval(-30 * 86_400)

        let english = ArticleTimestampFormatter.string(for: date, language: .english, now: now)
        let vietnamese = ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now)

        XCTAssertNotNil(english)
        XCTAssertNotNil(vietnamese)
        // Not a fixed pattern assertion: the point is that each language gets its own
        // conventional order rather than one hardcoded dd/MM/yyyy for everybody.
        XCTAssertNotEqual(english, vietnamese)
    }

    func test_givenArticleExactlySevenDaysOld_whenFormatting_thenStillRelative() {
        let date = now.addingTimeInterval(-7 * 86_400)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), "7 days ago")
    }
}
