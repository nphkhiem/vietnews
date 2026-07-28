import XCTest
@testable import VietNews

private final class FakeAdapter: NewsSourceAdapter {
    let source: NewsSource
    var supported: Bool
    var result: Result<[Article], Error>
    var delay: TimeInterval

    init(
        source: NewsSource,
        supported: Bool = true,
        result: Result<[Article], Error> = .success([]),
        delay: TimeInterval = 0
    ) {
        self.source = source
        self.supported = supported
        self.result = result
        self.delay = delay
    }

    func supports(category: NewsCategory, language: Language) -> Bool { supported }

    func endpoints(category: NewsCategory, language: Language) -> [URL] {
        supported ? [URL(string: "https://example.com/\(source.rawValue)")!] : []
    }

    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        if delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
        return try result.get()
    }
}

final class RemoteArticleRepositoryTests: XCTestCase {
    private func articles(_ count: Int, source: NewsSource, startingAt epoch: TimeInterval) -> [Article] {
        (0..<count).map { i in
            TestFactory.article(
                url: "https://\(source.rawValue).com/\(i)",
                source: source,
                publishedAt: Date(timeIntervalSince1970: epoch + TimeInterval(i))
            )
        }
    }

    func test_givenMultipleSuccessfulSources_whenFetching_thenMergesSortsAndCapsAt15() async throws {
        let a = FakeAdapter(source: .vnexpress, result: .success(articles(10, source: .vnexpress, startingAt: 1_000)))
        let b = FakeAdapter(source: .eurogamer, result: .success(articles(10, source: .eurogamer, startingAt: 2_000)))
        let sut = RemoteArticleRepository(adapters: [a, b])

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 15)
        XCTAssertTrue(result.failedSources.isEmpty)
        // newest first: all 10 eurogamer (epoch 2000+) precede vnexpress
        XCTAssertEqual(result.articles.first?.source, .eurogamer)
        let dates = result.articles.map { $0.publishedAt ?? .distantPast }
        XCTAssertEqual(dates, dates.sorted(by: >))
    }

    func test_givenOneSourceFails_whenFetching_thenReportsFailedSourceAndReturnsRest() async throws {
        let ok = FakeAdapter(source: .vnexpress, result: .success(articles(3, source: .vnexpress, startingAt: 1_000)))
        let bad = FakeAdapter(source: .bbc, result: .failure(NewsError.networkUnavailable))
        let sut = RemoteArticleRepository(adapters: [ok, bad])

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 3)
        XCTAssertEqual(result.failedSources, [.bbc])
    }

    func test_givenAllSourcesFail_whenFetching_thenThrowsNamingThoseSources() async {
        let bad1 = FakeAdapter(source: .vnexpress, result: .failure(NewsError.networkUnavailable))
        let bad2 = FakeAdapter(source: .bbc, result: .failure(NewsError.networkUnavailable))
        let sut = RemoteArticleRepository(adapters: [bad1, bad2])

        do {
            _ = try await sut.fetchArticles(category: .sport, language: .english)
            XCTFail("Expected throw")
        } catch {
            guard case .allSourcesFailed(let sources, let cause) = error as? NewsError else {
                return XCTFail("Expected allSourcesFailed, got \(error)")
            }
            XCTAssertEqual(Set(sources), [.vnexpress, .bbc])
            XCTAssertEqual(cause, .unreachable, "both adapters failed with the same cause")
        }
    }

    /// An adapter that does not support the request is not a failure, so it must never appear in
    /// the reported list even when every supported adapter fails.
    func test_givenAllSupportedSourcesFail_whenFetching_thenUnsupportedSourcesAreNotNamed() async {
        let bad = FakeAdapter(source: .vnexpress, result: .failure(NewsError.networkUnavailable))
        let unsupported = FakeAdapter(source: .nyt, supported: false)
        let sut = RemoteArticleRepository(adapters: [bad, unsupported])

        do {
            _ = try await sut.fetchArticles(category: .sport, language: .english)
            XCTFail("Expected throw")
        } catch {
            guard case .allSourcesFailed(let sources, _) = error as? NewsError else {
                return XCTFail("Expected allSourcesFailed, got \(error)")
            }
            XCTAssertEqual(sources, [.vnexpress])
        }
    }

    func test_givenUnsupportedAdapter_whenFetching_thenSkipsWithoutCountingAsFailure() async throws {
        let unsupported = FakeAdapter(
            source: .nyt, supported: false, result: .failure(NewsError.networkUnavailable)
        )
        let ok = FakeAdapter(source: .eurogamer, result: .success(articles(2, source: .eurogamer, startingAt: 1_000)))
        let sut = RemoteArticleRepository(adapters: [unsupported, ok])

        let result = try await sut.fetchArticles(category: .game, language: .english)

        XCTAssertEqual(result.articles.count, 2)
        XCTAssertTrue(result.failedSources.isEmpty)
    }

    func test_givenNoSupportingAdapters_whenFetching_thenReturnsEmptyResult() async throws {
        let unsupported = FakeAdapter(source: .nyt, supported: false)
        let sut = RemoteArticleRepository(adapters: [unsupported])

        let result = try await sut.fetchArticles(category: .game, language: .vietnamese)

        XCTAssertTrue(result.articles.isEmpty)
        XCTAssertTrue(result.failedSources.isEmpty)
    }

    func test_givenSlowSource_whenExceedingTimeout_thenReportedAsFailedSource() async throws {
        let slow = FakeAdapter(
            source: .bbc,
            result: .success(articles(5, source: .bbc, startingAt: 9_000)),
            delay: 2.0
        )
        let fast = FakeAdapter(source: .eurogamer, result: .success(articles(2, source: .eurogamer, startingAt: 1_000)))
        let sut = RemoteArticleRepository(adapters: [slow, fast], perSourceTimeout: 0.2)

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 2)
        XCTAssertEqual(result.failedSources, [.bbc])
    }

    func test_givenCustomMaxArticles_whenFetching_thenCapsAtConfiguredValue() async throws {
        let a = FakeAdapter(source: .vnexpress, result: .success(articles(40, source: .vnexpress, startingAt: 1_000)))
        let sut = RemoteArticleRepository(adapters: [a], maxArticles: { 30 })

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 30)
    }

    func test_givenSourcesFailingForDifferentReasons_whenAllFail_thenReportsAMixedCause() async {
        let timedOut = FakeAdapter(source: .vnexpress, result: .failure(NewsError.sourceTimeout(.vnexpress)))
        let refused = FakeAdapter(source: .bbc, result: .failure(NewsError.invalidResponse(statusCode: 403)))
        let sut = RemoteArticleRepository(adapters: [timedOut, refused])

        do {
            _ = try await sut.fetchArticles(category: .sport, language: .english)
            XCTFail("Expected throw")
        } catch {
            guard case .allSourcesFailed(_, let cause) = error as? NewsError else {
                return XCTFail("Expected allSourcesFailed, got \(error)")
            }
            XCTAssertEqual(cause, .mixed)
        }
    }

    func test_givenEverySourceRefusing_whenAllFail_thenReportsRejected() async {
        let a = FakeAdapter(source: .vnexpress, result: .failure(NewsError.invalidResponse(statusCode: 403)))
        let b = FakeAdapter(source: .bbc, result: .failure(NewsError.invalidResponse(statusCode: 404)))
        let sut = RemoteArticleRepository(adapters: [a, b])

        do {
            _ = try await sut.fetchArticles(category: .sport, language: .english)
            XCTFail("Expected throw")
        } catch {
            guard case .allSourcesFailed(_, let cause) = error as? NewsError else {
                return XCTFail("Expected allSourcesFailed, got \(error)")
            }
            XCTAssertEqual(cause, .rejected)
        }
    }

    /// Publishers reissue a story under a new headline at the same address, which gives two
    /// articles one identifier. A SwiftUI list handed duplicate identifiers renders one of them
    /// as an empty row, which is exactly what was observed in the feed.
    func test_givenTwoArticlesSharingAURL_whenFetching_thenOnlyOneSurvives() async throws {
        let url = "https://example.com/same-story"
        let reissued = TestFactory.article(
            url: url, title: "Reissued headline", source: .bbc,
            publishedAt: Date(timeIntervalSince1970: 2_000)
        )
        let original = TestFactory.article(
            url: url, title: "Original headline", source: .bbc,
            publishedAt: Date(timeIntervalSince1970: 1_000)
        )
        let other = TestFactory.article(
            url: "https://example.com/other", source: .bbc,
            publishedAt: Date(timeIntervalSince1970: 500)
        )
        let sut = RemoteArticleRepository(
            adapters: [FakeAdapter(source: .bbc, result: .success([reissued, original, other]))]
        )

        let result = try await sut.fetchArticles(category: .sport, language: .english)

        XCTAssertEqual(result.articles.count, 2)
        XCTAssertEqual(Set(result.articles.map(\.id)).count, 2, "identifiers must be unique")
        XCTAssertEqual(result.articles.first?.title, "Reissued headline", "the newest is kept")
    }
}
