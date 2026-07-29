import XCTest
@testable import VietNews

/// Atom and JSON were silently discarded while the README advertised Atom and the settings
/// screen invited any feed address at all.
final class FeedFormatTests: XCTestCase {
    private func fixture(_ name: String, _ ext: String) throws -> Data {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: name, withExtension: ext))
        return try Data(contentsOf: url)
    }

    // MARK: - Atom

    func test_givenAnAtomFeed_whenParsing_thenEntriesBecomeArticles() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_atom", "xml"))

        // The third entry has no link, so it is dropped rather than becoming a headline with
        // nowhere to go.
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "Inside a platform team")
        XCTAssertEqual(
            items[0].link.absoluteString,
            "https://newsletter.pragmaticengineer.com/p/platform-team"
        )
    }

    func test_givenAnAtomEntry_whenMapped_thenItsSummaryIsStrippedOfMarkup() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_atom", "xml"))

        XCTAssertEqual(items[0].summary, "How one company actually staffs its platform group.")
    }

    /// The alternate link is where a reader should be sent. Taking the first link would have
    /// sent them to an audio enclosure.
    func test_givenAnEntryWithSeveralLinks_whenMapped_thenTheAlternateWins() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_atom", "xml"))

        XCTAssertFalse(items[0].link.absoluteString.hasSuffix(".mp3"))
    }

    /// `published` is when it was written, `updated` is mandatory and moves. Preferring
    /// `published` stops a lightly edited old entry resurfacing at the top of the feed.
    func test_givenAnEntryWithBothDates_whenMapped_thenPublishedWins() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_atom", "xml"))

        XCTAssertEqual(items[0].publishedAt, ISO8601DateFormatter().date(from: "2026-07-19T08:30:00Z"))
    }

    func test_givenAnEntryWithOnlyUpdated_whenMapped_thenUpdatedIsUsed() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_atom", "xml"))

        XCTAssertEqual(items[1].publishedAt, ISO8601DateFormatter().date(from: "2026-07-18T08:30:00Z"))
    }

    func test_givenAnAtomEntryWithThumbnails_whenMapped_thenTheWidestIsTaken() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_atom", "xml"))

        XCTAssertEqual(items[0].imageURL?.absoluteString, "https://cdn.example.com/platform-960.jpg")
    }

    func test_givenAnAtomEntryWithOnlyContent_whenMapped_thenContentStandsInForTheSummary() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_atom", "xml"))

        XCTAssertEqual(items[1].summary, "Body text stands in.")
        XCTAssertEqual(items[1].imageURL?.absoluteString, "https://cdn.example.com/inline.jpg")
    }

    func test_givenAnAtomFeed_whenAskedItsName_thenTheChannelTitleIsReturned() throws {
        let title = FeedKitRSSParser().channelTitle(in: try fixture("generic_atom", "xml"))

        XCTAssertEqual(title, "The Pragmatic Engineer")
    }

    // MARK: - JSON

    func test_givenAJSONFeed_whenParsing_thenItemsBecomeArticles() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_json", "json"))

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "Growth loops that actually compound")
        XCTAssertEqual(items[0].summary, "Why most growth loops leak, and the three that do not.")
        XCTAssertEqual(items[0].imageURL?.absoluteString, "https://cdn.example.com/loops.jpg")
        XCTAssertEqual(items[0].publishedAt, ISO8601DateFormatter().date(from: "2026-07-19T08:30:00Z"))
    }

    func test_givenAJSONItemWithNoURL_whenMapped_thenTheExternalAddressIsUsed() throws {
        let items = try FeedKitRSSParser().parse(try fixture("generic_json", "json"))

        XCTAssertEqual(items[1].link.absoluteString, "https://example.com/external-only")
        XCTAssertEqual(items[1].imageURL?.absoluteString, "https://cdn.example.com/ext.jpg")
    }

    func test_givenAJSONFeed_whenAskedItsName_thenTheTitleIsReturned() throws {
        let title = FeedKitRSSParser().channelTitle(in: try fixture("generic_json", "json"))

        XCTAssertEqual(title, "Lenny's Newsletter")
    }

    // MARK: - Neither

    /// An unsupported or malformed feed reports a parse failure naming the source, rather than
    /// succeeding with nothing in it, which is indistinguishable from a publisher having a quiet
    /// day.
    func test_givenSomethingThatIsNotAFeed_whenParsing_thenItReportsAParseFailure() {
        let sut = FeedKitRSSParser(parsingSource: .substack)

        XCTAssertThrowsError(try sut.parse(Data("<html><body>not a feed</body></html>".utf8))) { error in
            XCTAssertEqual(error as? NewsError, .parsingFailed(.substack))
        }
    }

    func test_givenSomethingThatIsNotAFeed_whenAskedItsName_thenItReportsNoName() {
        XCTAssertNil(FeedKitRSSParser().channelTitle(in: Data("nonsense".utf8)))
    }
}
