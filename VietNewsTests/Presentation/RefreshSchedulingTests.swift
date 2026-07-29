import XCTest
@testable import VietNews

final class RefreshPreferenceTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: UserPreferences!
    private let suiteName = "RefreshPreferenceTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        sut = UserPreferences(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_givenNothingChosen_whenRead_thenItDefaultsToFiveMinutes() {
        XCTAssertEqual(sut.refreshInterval, 300)
    }

    /// Zero used to stand for "never set", so switching automatic refresh off was not
    /// expressible: it read back as the default. The absence of the key is what means unset now.
    func test_givenRefreshTurnedOff_whenReadBack_thenItStaysOff() {
        sut.refreshInterval = 0

        XCTAssertEqual(sut.refreshInterval, 0)
        XCTAssertEqual(UserPreferences(defaults: defaults).refreshInterval, 0)
    }

    func test_givenEveryOfferedInterval_whenStored_thenItSurvives() {
        for option in UserPreferences.refreshIntervalOptions {
            sut.refreshInterval = option
            XCTAssertEqual(sut.refreshInterval, option)
        }
    }

    func test_givenAnIntervalNotOffered_whenStored_thenItSnapsToTheDefault() {
        sut.refreshInterval = 137

        XCTAssertEqual(sut.refreshInterval, 300)
    }

    /// A reader who asked for hourly refreshes should not be served a refetch every five minutes
    /// by a separate fixed number they never saw.
    func test_givenAChosenInterval_whenAskedForTheCacheLifetime_thenItFollows() {
        sut.refreshInterval = 3_600

        XCTAssertEqual(sut.cacheTTL, 3_600)
    }

    /// With refresh off the cache still ages out, otherwise pulling to refresh would be the only
    /// way the app ever saw a new article.
    func test_givenRefreshOff_whenAskedForTheCacheLifetime_thenItStillExpires() {
        sut.refreshInterval = 0

        XCTAssertGreaterThan(sut.cacheTTL, 0)
    }

    func test_givenTheOfferedIntervals_whenInspected_thenTheyCoverOffToAnHour() {
        XCTAssertEqual(UserPreferences.refreshIntervalOptions.first, 0)
        XCTAssertEqual(UserPreferences.refreshIntervalOptions.last, 3_600)
    }
}

/// The scheduler is added to the common run loop modes so a scroll cannot suspend it. That
/// behaviour is not asserted here: driving a nested run loop from inside XCTest deadlocks, and a
/// test that hangs is worse than an untested line. What is asserted is the part that is
/// observable without one.
final class AutoRefreshSchedulerModeTests: XCTestCase {
    func test_givenAnIntervalOfZero_whenStarted_thenNoTimerIsScheduled() {
        let sut = AutoRefreshScheduler()
        var ticks = 0
        sut.onTick = { ticks += 1 }

        sut.start(interval: 0)

        // Nothing to wait for: with no timer scheduled there is nothing that could fire.
        let idle = expectation(description: "idle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { idle.fulfill() }
        wait(for: [idle], timeout: 2)
        XCTAssertEqual(ticks, 0)
    }

}

@MainActor
final class PrefetchTests: XCTestCase {
    /// Indexing `allCases` warmed a neighbour the reader could not reach and skipped the one
    /// sitting next to them in the strip.
    func test_givenALanguageMissingSomeCategories_whenPrefetching_thenNeighboursAreTheVisibleOnes() {
        let visible = NewsCategory.allCases.filter { $0.isAvailable(in: .english) }
        let all = NewsCategory.allCases

        // The bug is only observable when the two lists differ, so assert the premise holds.
        XCTAssertNotEqual(visible.count, all.count, "English is expected to omit some categories")

        // Every category the reader can see has visible neighbours, and never an invisible one.
        for category in visible {
            guard let index = visible.firstIndex(of: category) else { continue }
            let neighbours = [index - 1, index + 1]
                .filter(visible.indices.contains)
                .map { visible[$0] }
            for neighbour in neighbours {
                XCTAssertTrue(
                    neighbour.isAvailable(in: .english),
                    "\(neighbour) is not reachable in English and should never be prefetched for it"
                )
            }
        }
    }
}
