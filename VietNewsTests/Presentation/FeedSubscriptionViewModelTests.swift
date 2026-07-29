import XCTest
@testable import VietNews

/// Answers per URL, so a test can make one candidate address work and another fail.
private final class RoutedNetwork: NetworkService, @unchecked Sendable {
    var responses: [String: Result<Data, Error>] = [:]
    private(set) var requested: [URL] = []
    private let lock = NSLock()

    func data(from url: URL) async throws -> Data {
        lock.lock()
        requested.append(url)
        let result = responses[url.absoluteString] ?? .failure(URLError(.cannotConnectToHost))
        lock.unlock()
        return try result.get()
    }
}

@MainActor
final class FeedSubscriptionViewModelTests: XCTestCase {
    private var network: RoutedNetwork!
    private var parser: StubRSSParser!
    private var existing: [SubstackFeed] = []
    private var committed: [SubstackFeed] = []

    override func setUp() {
        super.setUp()
        network = RoutedNetwork()
        parser = StubRSSParser()
        existing = []
        committed = []
    }

    private func makeSUT() -> FeedSubscriptionViewModel {
        FeedSubscriptionViewModel(
            network: network,
            parser: parser,
            existingFeeds: { self.existing },
            commit: { self.committed.append($0) }
        )
    }

    private func item(_ title: String) -> RSSItemDTO {
        RSSItemDTO(
            title: title,
            link: URL(string: "https://example.com/\(title)")!,
            summary: "Summary",
            imageURL: nil,
            publishedAt: Date(timeIntervalSince1970: 1)
        )
    }

    // MARK: - Validation as it is typed

    func test_givenNothingTyped_whenValidating_thenNothingIsSaidYet() {
        // given
        let sut = makeSUT()

        // when
        sut.address = ""

        // then
        XCTAssertEqual(sut.addressState, .empty)
    }

    func test_givenAnAddressWithNoScheme_whenValidating_thenHTTPSIsAssumed() {
        // given
        let sut = makeSUT()

        // when
        sut.address = "example.com/feed"

        // then
        XCTAssertEqual(sut.addressState, .usable(URL(string: "https://example.com/feed")!))
    }

    /// Reported as our own rule rather than as a failure to reach it. App Transport Security
    /// would refuse it anyway, and "nothing answered" would be a misleading way to say so.
    func test_givenAnInsecureAddress_whenValidating_thenItIsRejectedAsInsecure() {
        // given
        let sut = makeSUT()

        // when
        sut.address = "http://example.com/feed"

        // then
        XCTAssertEqual(sut.addressState, .invalid(.insecure))
    }

    func test_givenSomethingThatIsNotAnAddress_whenValidating_thenItSaysSo() {
        // given
        let sut = makeSUT()
        let typed = ["not an address", "example", "https://.com"]

        // when
        let states = typed.map { address -> FeedSubscriptionViewModel.AddressState in
            sut.address = address
            return sut.addressState
        }

        // then
        for (address, state) in zip(typed, states) {
            XCTAssertEqual(state, .invalid(.notAnAddress), "for \(address)")
        }
    }

    /// Said before the reader waits for a preview of something they already follow.
    func test_givenAFeedAlreadyFollowed_whenValidating_thenItIsRejectedImmediately() {
        // given
        existing = [SubstackFeed(url: URL(string: "https://example.com/feed")!, category: .work)]
        let sut = makeSUT()

        // when
        sut.address = "example.com/feed"

        // then
        XCTAssertEqual(sut.addressState, .invalid(.alreadyFollowed))
    }

    func test_givenAValidatedAddress_whenEditedAgain_thenTheOldPreviewIsDiscarded() async {
        // given
        network.responses["https://example.com/feed"] = .success(Data("<rss/>".utf8))
        parser.items = [item("One")]
        let sut = makeSUT()
        sut.address = "example.com/feed"

        // when
        await sut.check()

        // then
        XCTAssertTrue(sut.canAdd)
        sut.address = "example.com/other"
        XCTAssertFalse(sut.canAdd, "a preview of the previous address must not survive an edit")
    }

    // MARK: - Preview

    func test_givenAWorkingFeed_whenChecked_thenItsNameAndRecentItemsAreShown() async {
        // given
        network.responses["https://example.com/feed"] = .success(Data("<rss/>".utf8))
        parser.items = [item("One"), item("Two"), item("Three"), item("Four")]
        parser.channelTitle = "Example Weekly"
        let sut = makeSUT()
        sut.address = "example.com/feed"

        // when
        await sut.check()

        // then
        guard case .found(let preview) = sut.previewState else {
            return XCTFail("expected a preview, got \(sut.previewState)")
        }
        XCTAssertEqual(preview.title, "Example Weekly")
        XCTAssertEqual(preview.itemTitles, ["One", "Two", "Three"])
        XCTAssertTrue(sut.canAdd)
    }

    /// Many publications sit at a bare domain with the feed one level down, and the reader
    /// should not have to know which.
    func test_givenABareDomain_whenChecked_thenItAlsoTriesTheFeedPath() async {
        // given
        network.responses["https://example.com/feed"] = .success(Data("<rss/>".utf8))
        parser.items = [item("One")]
        let sut = makeSUT()
        sut.address = "example.com"

        // when
        await sut.check()

        // then
        guard case .found(let preview) = sut.previewState else {
            return XCTFail("expected a preview, got \(sut.previewState)")
        }
        XCTAssertEqual(preview.resolved.absoluteString, "https://example.com/feed")
    }

    func test_givenNothingAnswers_whenChecked_thenItReportsBeingUnreachable() async {
        // given
        let sut = makeSUT()
        sut.address = "example.com/feed"

        // when
        await sut.check()

        // then
        XCTAssertEqual(sut.previewState, .failed(.unreachable))
        XCTAssertFalse(sut.canAdd)
    }

    /// An address that answers with something unreadable is a different problem from one that
    /// does not answer, and the reader is told which.
    func test_givenAnAddressThatIsNotAFeed_whenChecked_thenItReportsBeingUnreadable() async {
        // given
        network.responses["https://example.com/feed"] = .success(Data("<html/>".utf8))
        parser.shouldThrow = true
        let sut = makeSUT()
        sut.address = "example.com/feed"

        // when
        await sut.check()

        // then
        XCTAssertEqual(sut.previewState, .failed(.unreadable))
    }

    func test_givenAFeedWithNoName_whenChecked_thenItFallsBackToItsHost() async {
        // given
        network.responses["https://example.com/feed"] = .success(Data("<rss/>".utf8))
        parser.items = [item("One")]
        parser.channelTitle = nil
        let sut = makeSUT()
        sut.address = "example.com/feed"

        // when
        await sut.check()

        // then
        guard case .found(let preview) = sut.previewState else {
            return XCTFail("expected a preview, got \(sut.previewState)")
        }
        XCTAssertEqual(preview.title, "example.com")
    }

    // MARK: - Committing

    func test_givenAPreview_whenAdded_thenTheResolvedAddressIsSaved() async {
        // given
        network.responses["https://example.com/feed"] = .success(Data("<rss/>".utf8))
        parser.items = [item("One")]
        let sut = makeSUT()
        sut.address = "example.com"
        sut.category = .work

        // when
        await sut.check()

        // then
        XCTAssertTrue(sut.add())
        XCTAssertEqual(committed.map(\.url.absoluteString), ["https://example.com/feed"])
        XCTAssertEqual(committed.first?.category, .work)
    }

    func test_givenNoPreview_whenAdding_thenNothingIsSaved() {
        // given
        let sut = makeSUT()

        // when
        sut.address = "example.com/feed"

        // then
        XCTAssertFalse(sut.add())
        XCTAssertTrue(committed.isEmpty)
    }

    /// The address that answers is not always the one typed, so a duplicate can only be certain
    /// once it is resolved.
    func test_givenABareDomainResolvingToAFeedAlreadyFollowed_whenAdded_thenItIsRejected() async {
        // given
        network.responses["https://example.com/feed"] = .success(Data("<rss/>".utf8))
        parser.items = [item("One")]
        let sut = makeSUT()
        sut.address = "example.com"
        await sut.check()
        // Followed only after the preview, so the typed address passed validation cleanly.

        // when
        existing = [SubstackFeed(url: URL(string: "https://example.com/feed")!, category: .work)]

        // then
        XCTAssertFalse(sut.add())
        XCTAssertEqual(sut.previewState, .failed(.alreadyFollowed))
        XCTAssertTrue(committed.isEmpty)
    }
}
