import XCTest
@testable import VietNews

final class ArticleTimestampFormatterTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func test_givenArticleUnderOneHourOld_whenFormatting_thenShowsMinutesAgoEnglish() {
        // given
        let date = now.addingTimeInterval(-30 * 60)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertEqual(text, "30 minutes ago")
    }

    func test_givenArticleUnderOneDayOld_whenFormatting_thenShowsHoursAgoEnglish() {
        // given
        let date = now.addingTimeInterval(-5 * 3600)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertEqual(text, "5 hours ago")
    }

    func test_givenArticleOneHourOldExactly_whenFormatting_thenShowsSingularHourEnglish() {
        // given
        let date = now.addingTimeInterval(-1 * 3600)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertEqual(text, "1 hour ago")
    }

    func test_givenArticleBetweenOneAndSevenDaysOld_whenFormatting_thenShowsDaysAgoEnglish() {
        // given
        let date = now.addingTimeInterval(-3 * 86400)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertEqual(text, "3 days ago")
    }

    func test_givenArticleUnderOneDayOld_whenFormatting_thenShowsHoursAgoVietnamese() {
        // given
        let date = now.addingTimeInterval(-5 * 3600)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now)

        // then
        XCTAssertEqual(text, "5 giờ trước")
    }

    func test_givenArticleBetweenOneAndSevenDaysOld_whenFormatting_thenShowsDaysAgoVietnamese() {
        // given
        let date = now.addingTimeInterval(-3 * 86400)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now)

        // then
        XCTAssertEqual(text, "3 ngày trước")
    }

    /// Seven days is the boundary: still relative, not yet a calendar date.
    func test_givenArticleExactlySevenDaysOld_whenFormatting_thenShowsDaysAgo() {
        // given
        let date = now.addingTimeInterval(-7 * 86400)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertEqual(text, "7 days ago")
    }

    func test_givenNoDate_whenFormatting_thenShowsNothingRatherThanAFabricatedOne() {
        // given
        let date: Date? = nil

        // when
        let english = ArticleTimestampFormatter.string(for: date, language: .english, now: now)
        let vietnamese = ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now)

        // then
        XCTAssertNil(english)
        XCTAssertNil(vietnamese)
    }

    /// Feeds drift slightly ahead of the device clock, and that is not a broken date.
    func test_givenDateSlightlyInTheFuture_whenFormatting_thenTreatsItAsJustNow() {
        // given
        let date = now.addingTimeInterval(30)

        // when
        let english = ArticleTimestampFormatter.string(for: date, language: .english, now: now)
        let vietnamese = ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now)

        // then
        XCTAssertEqual(english, "Just now")
        XCTAssertEqual(vietnamese, "Vừa xong")
    }

    /// The bug this replaces: a date hours in the future rendered as "1 minute ago", claiming an
    /// article had just been published when its date was unusable.
    func test_givenDateFarInTheFuture_whenFormatting_thenShowsNothing() {
        // given
        let date = now.addingTimeInterval(6 * 3600)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertNil(text)
    }

    func test_givenArticleSecondsOld_whenFormatting_thenShowsJustNow() {
        // given
        let date = now.addingTimeInterval(-20)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertEqual(text, "Just now")
    }

    func test_givenArticleExactlyOneMinuteOld_whenFormatting_thenShowsSingularMinute() {
        // given
        let date = now.addingTimeInterval(-60)

        // when
        let text = ArticleTimestampFormatter.string(for: date, language: .english, now: now)

        // then
        XCTAssertEqual(text, "1 minute ago")
    }

    func test_givenArticleOlderThanAWeek_whenFormatting_thenUsesTheReadersOwnDateConventions() {
        // given
        let date = now.addingTimeInterval(-30 * 86_400)

        // when
        let english = ArticleTimestampFormatter.string(for: date, language: .english, now: now)
        let vietnamese = ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now)

        // then
        XCTAssertNotNil(english)
        XCTAssertNotNil(vietnamese)
        // Not a fixed pattern assertion: the point is that each language gets its own
        // conventional order rather than one hardcoded dd/MM/yyyy for everybody.
        XCTAssertNotEqual(english, vietnamese)
    }
}
