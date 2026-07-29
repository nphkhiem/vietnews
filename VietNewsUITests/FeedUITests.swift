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
        // given
        // `setUp` launched the app with the stub repository.

        // when
        let firstArticle = app.buttons[A11y.feedRow(category: "hotNews", index: 0)]

        // then
        XCTAssertTrue(firstArticle.waitForExistence(timeout: 5))
    }

    func test_givenFeedShown_whenSelectingSportCategory_thenSportStubArticlesAppear() {
        // given
        app.buttons[A11y.feedCategory("sport")].tap()

        // when
        let sportArticle = app.buttons[A11y.feedRow(category: "sport", index: 0)]

        // then
        XCTAssertTrue(sportArticle.waitForExistence(timeout: 5))
    }

    /// Proves the language switch took effect through observable behaviour rather than through
    /// display copy: Game is an English-only category and Social is Vietnamese-only, so the
    /// category strip itself reports which language is active.
    func test_givenSettingsShown_whenTogglingToEnglish_thenCategoryAvailabilityFollowsEnglish() {
        // given
        openSettings()
        selectLanguage(.english)
        app.tabBars.buttons.element(boundBy: 0).tap()

        // when
        let englishOnlyCategory = app.buttons[A11y.feedCategory("game")]

        // then
        XCTAssertTrue(englishOnlyCategory.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[A11y.feedCategory("social")].exists)
    }

    func test_givenEnglishSelected_whenTogglingBackToVietnamese_thenCategoryAvailabilityFollowsVietnamese() {
        // given
        openSettings()
        selectLanguage(.english)
        selectLanguage(.vietnamese)
        app.tabBars.buttons.element(boundBy: 0).tap()

        // when
        let vietnameseOnlyCategory = app.buttons[A11y.feedCategory("social")]

        // then
        XCTAssertTrue(vietnameseOnlyCategory.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[A11y.feedCategory("game")].exists)
    }

    /// A row must be reachable and activatable as a button. Before ticket 18 the row exposed no
    /// action at all, so the app's main interaction was unavailable to assistive technology.
    func test_givenFeedShown_whenInspectingARow_thenItIsAButtonCarryingItsHeadline() {
        // given
        // `setUp` launched the app with the stub repository.

        // when
        let row = app.buttons[A11y.feedRow(category: "hotNews", index: 0)]

        // then
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.isHittable)
        XCTAssertTrue(
            row.label.contains("Story 1"),
            "the row should read as one element carrying its headline, got: \(row.label)"
        )
    }

    func test_givenFeedShown_whenSelectingSettingsTab_thenSettingsScreenAppears() {
        // given
        // `setUp` launched the app on the feed.

        // when
        openSettings()

        // then
        XCTAssertTrue(app.buttons[A11y.settingsLanguageSegment("vi")].waitForExistence(timeout: 5))
    }

    /// The sources screen is where a broken source stops being a silent hole in the feed, so the
    /// route to it is worth holding onto.
    func test_givenSettingsShown_whenOpeningSources_thenEverySourceIsListedWithASwitch() {
        // given
        openSettings()

        // when
        let row = app.buttons[A11y.settingsSources]

        // then
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        // Matched on any element type: the row combines its children, so whether it surfaces as
        // a switch or as a plain element is SwiftUI's business, not the test's.
        let bbc = app.descendants(matching: .any)[A11y.sourcesRow(builtIn: "bbc")]
        XCTAssertTrue(bbc.waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches.firstMatch.exists)
    }

    /// Saving must not cost the reader their place: it happens from the feed, without the
    /// article opening.
    func test_givenAnArticleInTheFeed_whenSavedFromItsMenu_thenItAppearsInSavedWithoutOpening() {
        // given
        let row = app.buttons[A11y.feedRow(category: "hotNews", index: 0)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        // when
        row.press(forDuration: 1.2)
        let save = app.buttons[A11y.articleSaveAction]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()

        // then
        // Still on the feed: nothing was pushed or presented over it.
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        openSaved()
        XCTAssertTrue(app.buttons[A11y.savedRow(index: 0)].waitForExistence(timeout: 5))
    }

    func test_givenNothingSaved_whenOpeningSaved_thenItExplainsHowToSave() {
        // given
        // The UI test build uses a no-op cache, so nothing is ever saved.

        // when
        openSaved()

        // then
        XCTAssertTrue(
            app.descendants(matching: .any)[A11y.savedEmpty].waitForExistence(timeout: 5)
        )
    }

    /// Validation happens while the reader types, not on submit. An insecure address is our own
    /// rule and is refused before anything is attempted, so this needs no network.
    func test_givenAnInsecureAddress_whenTyped_thenTheSheetSaysSoBeforeAnythingIsAttempted() {
        // given
        openSettings()
        app.buttons[A11y.settingsSources].tap()

        // when
        let add = app.buttons[A11y.sourcesAddFeed]

        // then
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()
        let field = app.textFields[A11y.subscribeAddress]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("http://example.com/feed")
        XCTAssertTrue(app.staticTexts[A11y.subscribeProblem].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons[A11y.subscribeAction].isEnabled)
    }

    /// Search reads the cache and nothing else, so with an empty cache it reports no matches
    /// rather than an error. Nothing went wrong; there is simply nothing there by that name.
    func test_givenNothingCached_whenSearching_thenItReportsNoMatchesRatherThanAnError() {
        // given
        app.buttons[A11y.mastheadSearch].tap()

        // when
        let field = app.textFields[A11y.searchField]

        // then
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("chelsea")
        XCTAssertTrue(app.staticTexts[A11y.searchNoMatches].waitForExistence(timeout: 5))
    }

    /// Automatic refresh can be switched off, which the old five to ten minute slider could not
    /// express at all.
    func test_givenSettingsShown_whenTurningAutoRefreshOff_thenTheChoiceIsSelected() {
        // given
        openSettings()

        // when
        let off = app.buttons[A11y.refreshSegment(seconds: 0)]

        // then
        XCTAssertTrue(off.waitForExistence(timeout: 5))
        off.tap()
        XCTAssertTrue(off.isSelected)
    }

    /// Every screen title is the masthead now, so a pushed screen carries its own back control
    /// rather than the navigation bar it replaced.
    func test_givenAPushedScreen_whenGoingBack_thenTheMastheadCarriesTheWayOut() {
        // given
        openSettings()
        app.buttons[A11y.settingsSources].tap()

        // when
        let back = app.buttons[A11y.mastheadBack]

        // then
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        back.tap()
        XCTAssertTrue(app.buttons[A11y.settingsSources].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private enum PickerLanguage: String {
        case vietnamese = "vi"
        case english = "en"
    }

    private func openSettings() {
        app.tabBars.buttons.element(boundBy: 2).tap()
    }

    private func openSaved() {
        app.tabBars.buttons.element(boundBy: 1).tap()
    }

    private func selectLanguage(_ language: PickerLanguage) {
        let segment = app.buttons[A11y.settingsLanguageSegment(language.rawValue)]
        XCTAssertTrue(segment.waitForExistence(timeout: 5))
        segment.tap()
    }
}

/// Accessibility identifiers shared with the app target. Kept as plain strings so the UI test
/// bundle needs no import of the app, and so a copy or localization change can never break a
/// query.
enum A11y {
    static func settingsLanguageSegment(_ code: String) -> String { "settings.language.\(code)" }
    static let settingsSources = "settings.sources"
    static func sourcesRow(builtIn source: String) -> String { "sources.row.builtIn:\(source)" }

    static func feedCategory(_ rawValue: String) -> String { "feed.category.\(rawValue)" }
    static func feedRow(category: String, index: Int) -> String { "feed.row.\(category).\(index)" }
    static func savedRow(index: Int) -> String { "saved.row.\(index)" }
    static let savedEmpty = "saved.empty"
    static let articleSaveAction = "article.action.save"
    static let sourcesAddFeed = "sources.addFeed"
    static let subscribeAddress = "subscribe.address"
    static let subscribeProblem = "subscribe.problem"
    static let subscribeAction = "subscribe.action"
    static let mastheadSearch = "masthead.search"
    static let mastheadBack = "masthead.back"
    static let searchField = "search.field"
    static let searchNoMatches = "search.noMatches"
    static func refreshSegment(seconds: Int) -> String { "settings.refresh.\(seconds)" }
}
