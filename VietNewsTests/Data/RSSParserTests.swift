import XCTest
@testable import VietNews

final class RSSParserTests: XCTestCase {
    private func fixture(_ name: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle(for: Self.self).url(forResource: name, withExtension: "xml")
        )
        return try Data(contentsOf: url)
    }

    func test_givenVNExpressFeedXML_whenParsing_thenReturnsMappedItems() throws {
        // given
        let sut = FeedKitRSSParser()

        // when
        let items = try sut.parse(try fixture("vnexpress_sport"))

        // then
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].title, "Việt Nam thắng trận mở màn")
        XCTAssertEqual(
            items[0].link.absoluteString,
            "https://vnexpress.net/viet-nam-thang-tran-mo-man-4700001.html"
        )
        XCTAssertEqual(items[0].summary, "Đội tuyển giành chiến thắng 2-0 trong trận mở màn.")
        XCTAssertEqual(
            items[0].imageURL?.absoluteString,
            "https://i1-thethao.vnecdn.net/2026/07/10/doi-tuyen.jpg"
        )
        XCTAssertNotNil(items[0].publishedAt)
    }

    func test_givenItemWithoutImage_whenParsing_thenImageURLIsNil() throws {
        // given
        let sut = FeedKitRSSParser()
        let data = try fixture("vnexpress_sport")

        // when
        let items = try sut.parse(data)

        // then
        XCTAssertNil(items[1].imageURL)
        XCTAssertEqual(items[1].summary, "Plain description, no markup.")
    }

    func test_givenMalformedData_whenParsing_thenThrowsParsingFailed() {
        // given
        let sut = FeedKitRSSParser(parsingSource: .bbc)
        let malformed = Data("not xml at all".utf8)

        // when
        let parse = { try sut.parse(malformed) }

        // then
        XCTAssertThrowsError(try parse()) { error in
            XCTAssertEqual(error as? NewsError, .parsingFailed(.bbc))
        }
    }

    func test_givenHTMLString_whenStrippingHTML_thenReturnsPlainText() {
        // given
        let cases = [("<p>Hello <b>world</b></p>", "Hello world"), ("A &amp; B", "A & B")]

        // when
        let stripped = cases.map { $0.0.strippingHTML() }

        // then
        XCTAssertEqual(stripped, cases.map(\.1))
    }

    func test_givenHTMLWithImgTag_whenExtractingFirstImageURL_thenReturnsURL() {
        // given
        let html = #"<a href="x"><img src="https://cdn.site/img.jpg" /></a>text"#
        let withoutImage = "no image here"

        // when
        let found = html.firstImageURL()
        let missing = withoutImage.firstImageURL()

        // then
        XCTAssertEqual(found?.absoluteString, "https://cdn.site/img.jpg")
        XCTAssertNil(missing)
    }
}
