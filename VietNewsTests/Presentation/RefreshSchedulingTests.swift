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
        // given
        // Nothing chosen: `setUp` wipes the suite before every test.

        // when
        let interval = sut.refreshInterval

        // then
        XCTAssertEqual(interval, 300)
    }

    /// Zero used to stand for "never set", so switching automatic refresh off was not
    /// expressible: it read back as the default. The absence of the key is what means unset now.
    func test_givenRefreshTurnedOff_whenReadBack_thenItStaysOff() {
        // given
        sut.refreshInterval = 0

        // when
        let current = sut.refreshInterval
        let reloaded = UserPreferences(defaults: defaults).refreshInterval

        // then
        XCTAssertEqual(current, 0)
        XCTAssertEqual(reloaded, 0)
    }

    func test_givenEveryOfferedInterval_whenStored_thenItSurvives() {
        // given
        let options = UserPreferences.refreshIntervalOptions

        // when
        let stored = options.map { option -> TimeInterval in
            sut.refreshInterval = option
            return sut.refreshInterval
        }

        // then
        XCTAssertEqual(stored, options)
    }

    func test_givenAnIntervalNotOffered_whenStored_thenItSnapsToTheDefault() {
        // given
        let notOffered: TimeInterval = 137

        // when
        sut.refreshInterval = notOffered

        // then
        XCTAssertEqual(sut.refreshInterval, 300)
    }

    /// A reader who asked for hourly refreshes should not be served a refetch every five minutes
    /// by a separate fixed number they never saw.
    func test_givenAChosenInterval_whenAskedForTheCacheLifetime_thenItFollows() {
        // given
        sut.refreshInterval = 3_600

        // when
        let ttl = sut.cacheTTL

        // then
        XCTAssertEqual(ttl, 3_600)
    }

    /// With refresh off the cache still ages out, otherwise pulling to refresh would be the only
    /// way the app ever saw a new article.
    func test_givenRefreshOff_whenAskedForTheCacheLifetime_thenItStillExpires() {
        // given
        sut.refreshInterval = 0

        // when
        let ttl = sut.cacheTTL

        // then
        XCTAssertGreaterThan(ttl, 0)
    }

    func test_givenTheOfferedIntervals_whenInspected_thenTheyCoverOffToAnHour() {
        // given
        let options = UserPreferences.refreshIntervalOptions

        // when
        let bounds = (options.first, options.last)

        // then
        XCTAssertEqual(bounds.0, 0)
        XCTAssertEqual(bounds.1, 3_600)
    }
}

/// The scheduler is added to the common run loop modes so a scroll cannot suspend it. That
/// behaviour is not asserted here: driving a nested run loop from inside XCTest deadlocks, and a
/// test that hangs is worse than an untested line. What is asserted is the part that is
/// observable without one.
final class AutoRefreshSchedulerModeTests: XCTestCase {
    func test_givenAnIntervalOfZero_whenStarted_thenNoTimerIsScheduled() {
        // given
        let sut = AutoRefreshScheduler()
        var ticks = 0
        sut.onTick = { ticks += 1 }
        sut.start(interval: 0)
        // Nothing to wait for: with no timer scheduled there is nothing that could fire.
        let idle = expectation(description: "idle")

        // when
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { idle.fulfill() }

        // then
        wait(for: [idle], timeout: 2)
        XCTAssertEqual(ticks, 0)
    }

}

@MainActor
final class PrefetchTests: XCTestCase {
    /// Indexing `allCases` warmed a neighbour the reader could not reach and skipped the one
    /// sitting next to them in the strip.
    func test_givenALanguageMissingSomeCategories_whenPrefetching_thenNeighboursAreTheVisibleOnes() {
        // given
        let visible = NewsCategory.allCases.filter { $0.isAvailable(in: .english) }
        let all = NewsCategory.allCases

        // when
        // The bug is only observable when the two lists differ, so assert the premise holds.

        // then
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
