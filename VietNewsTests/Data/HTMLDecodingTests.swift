import XCTest
@testable import VietNews

final class HTMLDecodingTests: XCTestCase {
    func test_givenTags_whenStripping_thenRemovesThem() {
        // given
        let markup = "<p>Hello <b>world</b></p>"

        // when
        let stripped = markup.strippingHTML()

        // then
        XCTAssertEqual(stripped, "Hello world")
    }

    /// The bug this covers: only five entities were handled literally, so anything else stayed
    /// visible as raw text in the middle of a headline.
    func test_givenNumericReferences_whenStripping_thenResolvesThem() {
        // given
        let cases = [
            ("It&#8217;s here", "It\u{2019}s here"),
            ("caf&#233;", "café"),
            ("&#x1F600; hi", "\u{1F600} hi")
        ]

        // when
        let stripped = cases.map { $0.0.strippingHTML() }

        // then
        XCTAssertEqual(stripped, cases.map(\.1))
    }

    func test_givenNamedReferences_whenStripping_thenResolvesThem() {
        // given
        let cases = [
            ("A&nbsp;B", "A B"),
            ("one &mdash; two", "one \u{2014} two"),
            ("Tom &amp; Jerry", "Tom & Jerry")
        ]

        // when
        let stripped = cases.map { $0.0.strippingHTML() }

        // then
        XCTAssertEqual(stripped, cases.map(\.1))
    }

    /// Escaped text a publisher wrote deliberately must survive, rather than being mistaken for
    /// a tag and deleted.
    func test_givenEscapedComparison_whenStripping_thenKeepsTheText() {
        // given
        let markup = "5 &lt; 10 and 10 &gt; 5"

        // when
        let stripped = markup.strippingHTML()

        // then
        XCTAssertEqual(stripped, "5 < 10 and 10 > 5")
    }

    /// Resolving happens exactly once, so a double encoded payload becomes visible text rather
    /// than cascading back into markup that was already stripped.
    func test_givenDoubleEncodedMarkup_whenStripping_thenResolvesOnlyOneLevel() {
        // given
        let markup = "&amp;lt;script&amp;gt;"

        // when
        let stripped = markup.strippingHTML()

        // then
        XCTAssertEqual(stripped, "&lt;script&gt;")
    }

    func test_givenUnknownOrMalformedReference_whenStripping_thenLeavesItAlone() {
        // given
        let cases = [
            ("A &notarealentity; B", "A &notarealentity; B"),
            ("100% & rising", "100% & rising")
        ]

        // when
        let stripped = cases.map { $0.0.strippingHTML() }

        // then
        XCTAssertEqual(stripped, cases.map(\.1))
    }

    func test_givenRunsOfWhitespace_whenStripping_thenCollapsesThem() {
        // given
        let markup = "<p>Hello</p>   <p>world</p>"

        // when
        let stripped = markup.strippingHTML()

        // then
        XCTAssertEqual(stripped, "Hello world")
    }

    func test_givenDoubleQuotedImage_whenExtracting_thenFindsTheURL() {
        // given
        let html = #"<p><img src="https://example.com/a.jpg" alt="x"/>text</p>"#

        // when
        let url = html.firstImageURL()

        // then
        XCTAssertEqual(url?.absoluteString, "https://example.com/a.jpg")
    }

    /// Single quoted attributes appear in real feeds and previously lost the image silently.
    func test_givenSingleQuotedImage_whenExtracting_thenFindsTheURL() {
        // given
        let html = "<p><img src='https://example.com/b.jpg'/>text</p>"

        // when
        let url = html.firstImageURL()

        // then
        XCTAssertEqual(url?.absoluteString, "https://example.com/b.jpg")
    }

    func test_givenEncodedAmpersandInImageURL_whenExtracting_thenResolvesIt() {
        // given
        let html = #"<img src="https://example.com/i.jpg?a=1&amp;b=2">"#

        // when
        let url = html.firstImageURL()

        // then
        XCTAssertEqual(url?.absoluteString, "https://example.com/i.jpg?a=1&b=2")
    }

    func test_givenNoImage_whenExtracting_thenReturnsNil() {
        // given
        let html = "<p>no pictures here</p>"

        // when
        let url = html.firstImageURL()

        // then
        XCTAssertNil(url)
    }
}
