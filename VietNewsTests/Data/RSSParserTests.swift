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
        let sut = FeedKitRSSParser()

        let items = try sut.parse(try fixture("vnexpress_sport"))

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
        let items = try FeedKitRSSParser().parse(try fixture("vnexpress_sport"))
        XCTAssertNil(items[1].imageURL)
        XCTAssertEqual(items[1].summary, "Plain description, no markup.")
    }

    func test_givenMalformedData_whenParsing_thenThrowsParsingFailed() {
        let sut = FeedKitRSSParser(parsingSource: .reuters)
        XCTAssertThrowsError(try sut.parse(Data("not xml at all".utf8))) { error in
            XCTAssertEqual(error as? NewsError, .parsingFailed(.reuters))
        }
    }

    func test_givenHTMLString_whenStrippingHTML_thenReturnsPlainText() {
        XCTAssertEqual("<p>Hello <b>world</b></p>".strippingHTML(), "Hello world")
        XCTAssertEqual("A &amp; B".strippingHTML(), "A & B")
    }

    func test_givenHTMLWithImgTag_whenExtractingFirstImageURL_thenReturnsURL() {
        let html = #"<a href="x"><img src="https://cdn.site/img.jpg" /></a>text"#
        XCTAssertEqual(html.firstImageURL()?.absoluteString, "https://cdn.site/img.jpg")
        XCTAssertNil("no image here".firstImageURL())
    }
}
