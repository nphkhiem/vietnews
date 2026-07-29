import XCTest
@testable import VietNews

final class SourceIdentityTests: XCTestCase {
    func test_givenAnIdentity_whenRoundTrippedThroughItsKey_thenItSurvives() {
        let identities: [SourceIdentity] = [
            .builtIn(.bbc),
            .builtIn(.substack),
            .userFeed(URL(string: "https://newsletter.pragmaticengineer.com/feed")!)
        ]

        for identity in identities {
            XCTAssertEqual(SourceIdentity(key: identity.key), identity)
        }
    }

    /// The prefix exists so a feed hosted at a URL that reads like a source name cannot claim
    /// that source's record, or its switch.
    func test_givenAFeedURLResemblingASourceName_whenKeyed_thenItDoesNotCollide() {
        let feed = SourceIdentity.userFeed(URL(string: "https://bbc")!)

        XCTAssertNotEqual(feed.key, SourceIdentity.builtIn(.bbc).key)
        XCTAssertEqual(SourceIdentity(key: feed.key), feed)
    }

    func test_givenAnUnrecognizedKey_whenDecoded_thenItIsRejected() {
        XCTAssertNil(SourceIdentity(key: "builtIn:notASource"))
        XCTAssertNil(SourceIdentity(key: "wat:bbc"))
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
        XCTAssertEqual(sut.health(for: .builtIn(.nyt)), .unknown)
        XCTAssertTrue(sut.isEnabled(.builtIn(.nyt)))
    }

    func test_givenAFailure_whenItLaterSucceeds_thenTheFailureIsCleared() {
        let at = Date(timeIntervalSince1970: 1_000)
        sut.recordFailure(.builtIn(.bbc), cause: .timedOut)
        XCTAssertTrue(sut.health(for: .builtIn(.bbc)).isFailing)

        sut.recordSuccess(.builtIn(.bbc), at: at, publicationTitle: nil)

        let health = sut.health(for: .builtIn(.bbc))
        XCTAssertNil(health.lastFailure)
        XCTAssertEqual(health.lastSucceededAt, at)
    }

    /// Failing does not mean forgetting. A reader judging a broken source needs to know whether
    /// it worked an hour ago or has never worked at all.
    func test_givenASuccessThenAFailure_whenAsked_thenTheLastSuccessIsStillKnown() {
        let at = Date(timeIntervalSince1970: 2_000)
        sut.recordSuccess(.builtIn(.vnexpress), at: at, publicationTitle: nil)

        sut.recordFailure(.builtIn(.vnexpress), cause: .rejected)

        let health = sut.health(for: .builtIn(.vnexpress))
        XCTAssertEqual(health.lastFailure, .rejected)
        XCTAssertEqual(health.lastSucceededAt, at)
    }

    func test_givenAPublicationTitle_whenALaterSuccessOmitsIt_thenTheNameIsKept() {
        let feed = SourceIdentity.userFeed(URL(string: "https://example.com/feed")!)
        sut.recordSuccess(feed, at: Date(), publicationTitle: "The Pragmatic Engineer")

        sut.recordSuccess(feed, at: Date(), publicationTitle: nil)

        XCTAssertEqual(sut.health(for: feed).publicationTitle, "The Pragmatic Engineer")
    }

    func test_givenASourceSwitchedOff_whenReadBack_thenItStaysOffAndOthersAreUnaffected() {
        sut.setEnabled(false, for: .builtIn(.eurogamer))

        XCTAssertFalse(sut.isEnabled(.builtIn(.eurogamer)))
        XCTAssertTrue(sut.isEnabled(.builtIn(.bbc)))

        sut.setEnabled(true, for: .builtIn(.eurogamer))
        XCTAssertTrue(sut.isEnabled(.builtIn(.eurogamer)))
    }

    /// Records are written from inside a concurrent fetch. Without the lock, two sources
    /// finishing at once each write back a map that predates the other and one record vanishes.
    func test_givenConcurrentRecords_whenAllComplete_thenNoneAreLost() {
        let sources = NewsSource.allCases
        let done = expectation(description: "records written")
        done.expectedFulfillmentCount = sources.count

        for source in sources {
            DispatchQueue.global().async {
                self.sut.recordSuccess(.builtIn(source), at: Date(timeIntervalSince1970: 1), publicationTitle: nil)
                done.fulfill()
            }
        }
        wait(for: [done], timeout: 5)

        for source in sources {
            XCTAssertNotNil(
                sut.health(for: .builtIn(source)).lastSucceededAt,
                "\(source) lost its record to a concurrent write"
            )
        }
    }
}
