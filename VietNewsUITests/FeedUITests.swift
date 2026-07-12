import XCTest

final class FeedUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()
    }

    func test_givenAppLaunch_whenFeedTabShown_thenStubArticlesAreDisplayed() {
        let firstArticle = app.staticTexts["Tin nóng Story 1"]

        XCTAssertTrue(firstArticle.waitForExistence(timeout: 5))
    }

    func test_givenFeedShown_whenSelectingSportCategory_thenSportStubArticlesAppear() {
        app.buttons["Thể thao"].tap()

        let sportArticle = app.staticTexts["Thể thao Story 1"]
        XCTAssertTrue(sportArticle.waitForExistence(timeout: 5))
    }

    func test_givenSettingsShown_whenTogglingToEnglish_thenLanguageSectionHeaderSwitchesToEnglish() {
        app.tabBars.buttons["Cài đặt"].tap()
        app.segmentedControls.buttons["English"].tap()

        XCTAssertTrue(app.staticTexts["Language"].waitForExistence(timeout: 5))
    }

    func test_givenFeedShown_whenSelectingSettingsTab_thenSettingsScreenAppears() {
        app.tabBars.buttons["Cài đặt"].tap()

        XCTAssertTrue(app.navigationBars["Cài đặt"].waitForExistence(timeout: 5))
    }
}
