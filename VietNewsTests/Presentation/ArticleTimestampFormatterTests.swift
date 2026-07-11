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

    func test_givenArticleOlderThanSevenDays_whenFormatting_thenShowsAbsoluteDate() {
        let date = now.addingTimeInterval(-10 * 86400)
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents([.day, .month, .year], from: date)
        let expected = String(
            format: "%02d/%02d/%04d", components.day!, components.month!, components.year!
        )
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .english, now: now), expected)
    }

    func test_givenArticleUnderOneDayOld_whenFormatting_thenShowsHoursAgoVietnamese() {
        let date = now.addingTimeInterval(-5 * 3600)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now), "5 giờ trước")
    }

    func test_givenArticleBetweenOneAndSevenDaysOld_whenFormatting_thenShowsDaysAgoVietnamese() {
        let date = now.addingTimeInterval(-3 * 86400)
        XCTAssertEqual(ArticleTimestampFormatter.string(for: date, language: .vietnamese, now: now), "3 ngày trước")
    }
}
