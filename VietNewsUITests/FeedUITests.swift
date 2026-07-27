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
        let firstArticle = app.staticTexts[A11y.feedRow(category: "hotNews", index: 0)]

        XCTAssertTrue(firstArticle.waitForExistence(timeout: 5))
    }

    func test_givenFeedShown_whenSelectingSportCategory_thenSportStubArticlesAppear() {
        app.buttons[A11y.feedCategory("sport")].tap()

        let sportArticle = app.staticTexts[A11y.feedRow(category: "sport", index: 0)]
        XCTAssertTrue(sportArticle.waitForExistence(timeout: 5))
    }

    /// Proves the language switch took effect through observable behaviour rather than through
    /// display copy: Game is an English-only category and Social is Vietnamese-only, so the
    /// category strip itself reports which language is active.
    func test_givenSettingsShown_whenTogglingToEnglish_thenCategoryAvailabilityFollowsEnglish() {
        openSettings()
        selectLanguage(.english)
        app.tabBars.buttons.element(boundBy: 0).tap()

        let englishOnlyCategory = app.buttons[A11y.feedCategory("game")]
        XCTAssertTrue(englishOnlyCategory.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[A11y.feedCategory("social")].exists)
    }

    func test_givenEnglishSelected_whenTogglingBackToVietnamese_thenCategoryAvailabilityFollowsVietnamese() {
        openSettings()
        selectLanguage(.english)
        selectLanguage(.vietnamese)
        app.tabBars.buttons.element(boundBy: 0).tap()

        let vietnameseOnlyCategory = app.buttons[A11y.feedCategory("social")]
        XCTAssertTrue(vietnameseOnlyCategory.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[A11y.feedCategory("game")].exists)
    }

    func test_givenFeedShown_whenSelectingSettingsTab_thenSettingsScreenAppears() {
        openSettings()

        XCTAssertTrue(app.segmentedControls[A11y.settingsLanguagePicker].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private enum PickerLanguage: Int {
        case vietnamese = 0
        case english = 1
    }

    private func openSettings() {
        app.tabBars.buttons.element(boundBy: 1).tap()
    }

    private func selectLanguage(_ language: PickerLanguage) {
        let picker = app.segmentedControls[A11y.settingsLanguagePicker]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        picker.buttons.element(boundBy: language.rawValue).tap()
    }
}

/// Accessibility identifiers shared with the app target. Kept as plain strings so the UI test
/// bundle needs no import of the app, and so a copy or localization change can never break a
/// query.
enum A11y {
    static let settingsLanguagePicker = "settings.language.picker"

    static func feedCategory(_ rawValue: String) -> String { "feed.category.\(rawValue)" }
    static func feedRow(category: String, index: Int) -> String { "feed.row.\(category).\(index)" }
}
