import XCTest

final class SmokeUITests: XCTestCase {
    func test_givenAppLaunches_whenLaunched_thenDoesNotCrash() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
    }
}
