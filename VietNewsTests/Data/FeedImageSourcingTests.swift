import XCTest
@testable import VietNews

/// Covers where an article's image comes from. Image coverage measured 52% before this, entirely
/// because two elements real feeds use were never read.
final class FeedImageSourcingTests: XCTestCase {
    private func fixture(_ name: String, _ ext: String = "xml") throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: ext),
            "missing fixture \(name).\(ext)"
        )
        return try Data(contentsOf: url)
    }

    /// BBC publishes `media:thumbnail` and nothing else. Every one of its articles measured as
    /// having no image, which read as a property of the feed rather than of our parser.
    func test_givenFeedUsingMediaThumbnail_whenParsing_thenEveryItemHasAnImage() throws {
        let sut = FeedKitRSSParser(parsingSource: .bbc)

        let items = try sut.parse(try fixture("bbc_media_thumbnail"))

        XCTAssertFalse(items.isEmpty)
        for item in items {
            XCTAssertNotNil(item.imageURL, "no image for \(item.title)")
        }
    }

    func test_givenFeedUsingMediaContent_whenParsing_thenEveryItemHasAnImage() throws {
        let sut = FeedKitRSSParser(parsingSource: .eurogamer)

        let items = try sut.parse(try fixture("eurogamer_media_content"))

        XCTAssertFalse(items.isEmpty)
        for item in items {
            XCTAssertNotNil(item.imageURL, "no image for \(item.title)")
        }
    }

    /// The existing paths must keep working, since VNExpress relies on an image tag inside the
    /// description and other feeds use an enclosure.
    func test_givenFeedUsingAnImageTagInTheDescription_whenParsing_thenStillFindsIt() throws {
        let sut = FeedKitRSSParser(parsingSource: .vnexpress)

        let items = try sut.parse(try fixture("vnexpress_sport"))

        XCTAssertFalse(items.isEmpty)
        XCTAssertNotNil(items.first?.imageURL)
    }

    /// Feeds list renditions in no reliable order, and the widest is the one that survives being
    /// shown as a full width lead.
    func test_givenSeveralThumbnails_whenParsing_thenTakesTheWidest() throws {
        let feed = Self.rss(item: """
        <media:thumbnail width="240" height="135" url="https://example.com/small.jpg"/>
        <media:thumbnail width="976" height="549" url="https://example.com/large.jpg"/>
        <media:thumbnail width="480" height="270" url="https://example.com/medium.jpg"/>
        """)

        let items = try FeedKitRSSParser().parse(Data(feed.utf8))

        XCTAssertEqual(items.first?.imageURL?.absoluteString, "https://example.com/large.jpg")
    }

    /// A media:content element describes video and audio too, so it is only usable when it says
    /// which it is.
    func test_givenMediaContentThatIsNotAnImage_whenParsing_thenIgnoresIt() throws {
        let feed = Self.rss(item: """
        <media:content medium="video" url="https://example.com/clip.mp4"/>
        <media:thumbnail width="300" url="https://example.com/poster.jpg"/>
        """)

        let items = try FeedKitRSSParser().parse(Data(feed.utf8))

        XCTAssertEqual(items.first?.imageURL?.absoluteString, "https://example.com/poster.jpg")
    }

    func test_givenItemWithNoImageAnywhere_whenParsing_thenStillProducesTheArticle() throws {
        let items = try FeedKitRSSParser().parse(Data(Self.rss(item: "").utf8))

        XCTAssertEqual(items.count, 1)
        XCTAssertNil(items.first?.imageURL)
        XCTAssertEqual(items.first?.title, "Headline")
    }

    private static func rss(item: String) -> String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0" xmlns:media="http://search.yahoo.com/mrss/">
        <channel><title>T</title><link>https://example.com</link><description>d</description>
        <item>
        <title>Headline</title>
        <link>https://example.com/a</link>
        <description>Body text.</description>
        \(item)
        </item>
        </channel></rss>
        """
    }
}

/// Covers asking a width-templated CDN for a rendition that suits what is being displayed.
final class ImageVariantTests: XCTestCase {
    func test_givenBBCTemplatedURL_whenRequestingALargeWidth_thenRewritesIt() {
        let url = URL(string: "https://ichef.bbci.co.uk/ace/standard/240/cpsprodpb/ab/live/x.jpg")!

        let result = ImageVariant.url(url, targetingWidth: 900)

        XCTAssertEqual(
            result.absoluteString,
            "https://ichef.bbci.co.uk/ace/standard/976/cpsprodpb/ab/live/x.jpg"
        )
    }

    func test_givenTemplatedURL_whenRequestingASmallWidth_thenLeavesTheAdvertisedOne() {
        let url = URL(string: "https://ichef.bbci.co.uk/ace/standard/240/cpsprodpb/ab/live/x.jpg")!

        // The advertised rendition is known to exist; a narrower one may not.
        XCTAssertEqual(ImageVariant.url(url, targetingWidth: 100), url)
    }

    func test_givenVNExpressResizeURL_whenRequestingALargeWidth_thenRewritesIt() {
        let url = URL(string: "https://i1-vnexpress.vnecdn.net/resize_320x180/2026/07/a.jpg")!

        let result = ImageVariant.url(url, targetingWidth: 700)

        XCTAssertTrue(
            result.absoluteString.contains("resize_800x180"),
            "expected a wider rendition, got \(result.absoluteString)"
        )
    }

    /// Guessing at an unfamiliar URL's structure risks turning a working image into a 404.
    func test_givenUntemplatedURL_whenRequesting_thenReturnsItUnchanged() {
        let url = URL(string: "https://assetsio.gnwcdn.com/big-walk.jpg?width=690&quality=85")!

        XCTAssertEqual(ImageVariant.url(url, targetingWidth: 900), url)
    }

    func test_givenAnyWidth_whenRewriting_thenUsesAWidthTheCDNIsLikelyToHave() {
        let url = URL(string: "https://ichef.bbci.co.uk/ace/standard/240/x.jpg")!

        // 500 is not a rendition anyone publishes; the next one up the ladder is.
        XCTAssertEqual(
            ImageVariant.url(url, targetingWidth: 500).absoluteString,
            "https://ichef.bbci.co.uk/ace/standard/640/x.jpg"
        )
    }
}
