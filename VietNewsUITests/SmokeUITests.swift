import XCTest

final class SmokeUITests: XCTestCase {
    func test_givenAppLaunches_whenLaunched_thenDoesNotCrash() {
        // given
        let app = XCUIApplication()

        // when
        app.launch()

        // then
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
