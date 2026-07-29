import XCTest
@testable import VietNews

final class SourceIdentityTests: XCTestCase {
    func test_givenAnIdentity_whenRoundTrippedThroughItsKey_thenItSurvives() {
        // given
        let identities: [SourceIdentity] = [
            .builtIn(.bbc),
            .builtIn(.substack),
            .userFeed(URL(string: "https://newsletter.pragmaticengineer.com/feed")!)
        ]

        // when
        let roundTripped = identities.map { SourceIdentity(key: $0.key) }

        // then
        XCTAssertEqual(roundTripped, identities)
    }

    /// The prefix exists so a feed hosted at a URL that reads like a source name cannot claim
    /// that source's record, or its switch.
    func test_givenAFeedURLResemblingASourceName_whenKeyed_thenItDoesNotCollide() {
        // given
        let feed = SourceIdentity.userFeed(URL(string: "https://bbc")!)
        let builtIn = SourceIdentity.builtIn(.bbc)

        // when
        let feedKey = feed.key
        let builtInKey = builtIn.key

        // then
        XCTAssertNotEqual(feedKey, builtInKey)
        XCTAssertEqual(SourceIdentity(key: feedKey), feed)
    }

    func test_givenAnUnrecognizedKey_whenDecoded_thenItIsRejected() {
        // given
        let unrecognized = ["builtIn:notASource", "wat:bbc"]

        // when
        let decoded = unrecognized.map { SourceIdentity(key: $0) }

        // then
        XCTAssertTrue(decoded.allSatisfy { $0 == nil })
    }
}

final class DefaultsSourceHealthRepositoryTests: XCTestCase {
    private var defaults: UserDefaults!
    private var sut: DefaultsSourceHealthRepository!
    private let suiteName = "DefaultsSourceHealthRepositoryTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
        sut = DefaultsSourceHealthRepository(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_givenNoRecord_whenAsked_thenTheSourceIsUnknownAndOn() {
        // given
        let identity = SourceIdentity.builtIn(.nyt)

        // when
        let health = sut.health(for: identity)
        let isEnabled = sut.isEnabled(identity)

        // then
        XCTAssertEqual(health, .unknown)
        XCTAssertTrue(isEnabled)
    }

    func test_givenAFailure_whenItLaterSucceeds_thenTheFailureIsCleared() {
        // given
        let at = Date(timeIntervalSince1970: 1_000)

        // when
        sut.recordFailure(.builtIn(.bbc), cause: .timedOut)

        // then
        XCTAssertTrue(sut.health(for: .builtIn(.bbc)).isFailing)
        sut.recordSuccess(.builtIn(.bbc), at: at, publicationTitle: nil)
        let health = sut.health(for: .builtIn(.bbc))
        XCTAssertNil(health.lastFailure)
        XCTAssertEqual(health.lastSucceededAt, at)
    }

    /// Failing does not mean forgetting. A reader judging a broken source needs to know whether
    /// it worked an hour ago or has never worked at all.
    func test_givenASuccessThenAFailure_whenAsked_thenTheLastSuccessIsStillKnown() {
        // given
        let at = Date(timeIntervalSince1970: 2_000)
        sut.recordSuccess(.builtIn(.vnexpress), at: at, publicationTitle: nil)
        sut.recordFailure(.builtIn(.vnexpress), cause: .rejected)

        // when
        let health = sut.health(for: .builtIn(.vnexpress))

        // then
        XCTAssertEqual(health.lastFailure, .rejected)
        XCTAssertEqual(health.lastSucceededAt, at)
    }

    func test_givenAPublicationTitle_whenALaterSuccessOmitsIt_thenTheNameIsKept() {
        // given
        let feed = SourceIdentity.userFeed(URL(string: "https://example.com/feed")!)
        sut.recordSuccess(feed, at: Date(), publicationTitle: "The Pragmatic Engineer")

        // when
        sut.recordSuccess(feed, at: Date(), publicationTitle: nil)

        // then
        XCTAssertEqual(sut.health(for: feed).publicationTitle, "The Pragmatic Engineer")
    }

    func test_givenASourceSwitchedOff_whenReadBack_thenItStaysOffAndOthersAreUnaffected() {
        // given
        let switched = SourceIdentity.builtIn(.eurogamer)
        let untouched = SourceIdentity.builtIn(.bbc)

        // when
        sut.setEnabled(false, for: switched)
        let offAfterDisabling = !sut.isEnabled(switched)
        let neighbourStillOn = sut.isEnabled(untouched)
        sut.setEnabled(true, for: switched)
        let onAfterEnabling = sut.isEnabled(switched)

        // then
        XCTAssertTrue(offAfterDisabling)
        XCTAssertTrue(neighbourStillOn)
        XCTAssertTrue(onAfterEnabling)
    }

    /// Records are written from inside a concurrent fetch. Without the lock, two sources
    /// finishing at once each write back a map that predates the other and one record vanishes.
    func test_givenConcurrentRecords_whenAllComplete_thenNoneAreLost() {
        // given
        let sources = NewsSource.allCases
        let done = expectation(description: "records written")
        done.expectedFulfillmentCount = sources.count

        // when
        for source in sources {
            DispatchQueue.global().async {
                self.sut.recordSuccess(.builtIn(source), at: Date(timeIntervalSince1970: 1), publicationTitle: nil)
                done.fulfill()
            }
        }

        // then
        wait(for: [done], timeout: 5)
        for source in sources {
            XCTAssertNotNil(
                sut.health(for: .builtIn(source)).lastSucceededAt,
                "\(source) lost its record to a concurrent write"
            )
        }
    }
}
