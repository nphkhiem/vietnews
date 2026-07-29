import XCTest
@testable import VietNews

final class SmokeTests: XCTestCase {
    func test_givenTestTarget_whenLinkedAgainstApp_thenRunsSuccessfully() {
        // given
        // The test target links against the app; if that link were broken this would not build.
        let appType = NewsFeedViewModel.self

        // when
        let name = String(describing: appType)

        // then
        XCTAssertEqual(name, "NewsFeedViewModel")
    }
}
