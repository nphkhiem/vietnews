import XCTest
@testable import VietNews

final class HTMLDecodingTests: XCTestCase {
    func test_givenTags_whenStripping_thenRemovesThem() {
        XCTAssertEqual("<p>Hello <b>world</b></p>".strippingHTML(), "Hello world")
    }

    /// The bug this covers: only five entities were handled literally, so anything else stayed
    /// visible as raw text in the middle of a headline.
    func test_givenNumericReferences_whenStripping_thenResolvesThem() {
        XCTAssertEqual("It&#8217;s here".strippingHTML(), "It\u{2019}s here")
        XCTAssertEqual("caf&#233;".strippingHTML(), "café")
        XCTAssertEqual("&#x1F600; hi".strippingHTML(), "\u{1F600} hi")
    }

    func test_givenNamedReferences_whenStripping_thenResolvesThem() {
        XCTAssertEqual("A&nbsp;B".strippingHTML(), "A B")
        XCTAssertEqual("one &mdash; two".strippingHTML(), "one \u{2014} two")
        XCTAssertEqual("Tom &amp; Jerry".strippingHTML(), "Tom & Jerry")
    }

    /// Escaped text a publisher wrote deliberately must survive, rather than being mistaken for
    /// a tag and deleted.
    func test_givenEscapedComparison_whenStripping_thenKeepsTheText() {
        XCTAssertEqual("5 &lt; 10 and 10 &gt; 5".strippingHTML(), "5 < 10 and 10 > 5")
    }

    /// Resolving happens exactly once, so a double encoded payload becomes visible text rather
    /// than cascading back into markup that was already stripped.
    func test_givenDoubleEncodedMarkup_whenStripping_thenResolvesOnlyOneLevel() {
        XCTAssertEqual("&amp;lt;script&amp;gt;".strippingHTML(), "&lt;script&gt;")
    }

    func test_givenUnknownOrMalformedReference_whenStripping_thenLeavesItAlone() {
        XCTAssertEqual("A &notarealentity; B".strippingHTML(), "A &notarealentity; B")
        XCTAssertEqual("100% & rising".strippingHTML(), "100% & rising")
    }

    func test_givenRunsOfWhitespace_whenStripping_thenCollapsesThem() {
        XCTAssertEqual("<p>Hello</p>   <p>world</p>".strippingHTML(), "Hello world")
    }

    func test_givenDoubleQuotedImage_whenExtracting_thenFindsTheURL() {
        let html = #"<p><img src="https://example.com/a.jpg" alt="x"/>text</p>"#
        XCTAssertEqual(html.firstImageURL()?.absoluteString, "https://example.com/a.jpg")
    }

    /// Single quoted attributes appear in real feeds and previously lost the image silently.
    func test_givenSingleQuotedImage_whenExtracting_thenFindsTheURL() {
        let html = "<p><img src='https://example.com/b.jpg'/>text</p>"
        XCTAssertEqual(html.firstImageURL()?.absoluteString, "https://example.com/b.jpg")
    }

    func test_givenEncodedAmpersandInImageURL_whenExtracting_thenResolvesIt() {
        let html = #"<img src="https://example.com/i.jpg?a=1&amp;b=2">"#
        XCTAssertEqual(html.firstImageURL()?.absoluteString, "https://example.com/i.jpg?a=1&b=2")
    }

    func test_givenNoImage_whenExtracting_thenReturnsNil() {
        XCTAssertNil("<p>no pictures here</p>".firstImageURL())
    }
}
