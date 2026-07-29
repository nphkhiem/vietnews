import XCTest
import Foundation
import UIKit
@testable import VietNews

final class MockArticleRepository: ArticleRepository {
    var result: Result<FetchResult, Error> = .success(FetchResult(articles: [], failedSources: []))
    private(set) var fetchCallCount = 0
    private(set) var lastCategory: NewsCategory?
    private(set) var lastLanguage: Language?

    /// When set, `fetchArticles` for this category suspends until `releaseGatedFetch()` is
    /// called, letting tests deterministically drive interleaving of concurrent fetches
    /// (e.g. proving a slow, stale request doesn't overwrite a faster, newer one).
    private var gatedCategory: NewsCategory?
    private var gateContinuation: CheckedContinuation<Void, Never>?
    private(set) var didEnterGatedFetch = false

    func gateFetch(for category: NewsCategory) {
        gatedCategory = category
    }

    func releaseGatedFetch() {
        gateContinuation?.resume()
        gateContinuation = nil
    }

    func fetchArticles(category: NewsCategory, language: Language) async throws -> FetchResult {
        fetchCallCount += 1
        lastCategory = category
        lastLanguage = language
        let outcome = result
        if category == gatedCategory {
            didEnterGatedFetch = true
            await withCheckedContinuation { gateContinuation = $0 }
        }
        return try outcome.get()
    }
}

final class MockCacheRepository: CacheRepository {
    var stored: [String: CachedArticles] = [:]
    private(set) var saveCallCount = 0
    private(set) var clearAllCallCount = 0

    private func key(_ category: NewsCategory, _ language: Language) -> String {
        "\(category.rawValue)_\(language.rawValue)"
    }

    func save(_ entry: CachedArticles, category: NewsCategory, language: Language) throws {
        saveCallCount += 1
        stored[key(category, language)] = entry
    }

    func load(category: NewsCategory, language: Language) -> CachedArticles? {
        stored[key(category, language)]
    }

    func clearAll() throws {
        clearAllCallCount += 1
        stored.removeAll()
    }

    func totalSizeInBytes() -> Int { stored.count * 1_024 }
}

actor StubNetworkService: NetworkService {
    var result: Result<Data, Error> = .success(Data())
    private(set) var requestedURLs: [URL] = []

    func data(from url: URL) async throws -> Data {
        requestedURLs.append(url)
        return try result.get()
    }

    func setResult(_ newResult: Result<Data, Error>) {
        result = newResult
    }
}

final class StubRSSParser: RSSParsing {
    var items: [RSSItemDTO] = []
    var channelTitle: String?
    /// Lets a test hand back something that answered but is not a feed, which is a different
    /// outcome from nothing answering at all.
    var shouldThrow = false

    func parse(_ data: Data) throws -> [RSSItemDTO] {
        if shouldThrow { throw NewsError.parsingFailed(.substack) }
        return items
    }

    func channelTitle(in data: Data) -> String? { channelTitle }
}

/// In memory source health, so a test can put a source into any state without reaching
/// `UserDefaults` or waiting for a fetch to fail.
final class MockSourceHealthRepository: SourceHealthRepository, @unchecked Sendable {
    private(set) var records: [String: SourceHealth] = [:]
    private var disabled: Set<String> = []
    private let lock = NSLock()

    func health(for identity: SourceIdentity) -> SourceHealth {
        lock.lock(); defer { lock.unlock() }
        return records[identity.key] ?? .unknown
    }

    func recordSuccess(_ identity: SourceIdentity, at date: Date, publicationTitle: String?) {
        lock.lock(); defer { lock.unlock() }
        var record = records[identity.key] ?? .unknown
        record.lastSucceededAt = date
        record.lastFailure = nil
        if let publicationTitle, !publicationTitle.isEmpty {
            record.publicationTitle = publicationTitle
        }
        records[identity.key] = record
    }

    func recordFailure(_ identity: SourceIdentity, cause: SourceFailureCause) {
        lock.lock(); defer { lock.unlock() }
        var record = records[identity.key] ?? .unknown
        record.lastFailure = cause
        records[identity.key] = record
    }

    func isEnabled(_ identity: SourceIdentity) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return !disabled.contains(identity.key)
    }

    func setEnabled(_ isEnabled: Bool, for identity: SourceIdentity) {
        lock.lock(); defer { lock.unlock() }
        if isEnabled { disabled.remove(identity.key) } else { disabled.insert(identity.key) }
    }
}

enum TestFactory {
    static func article(
        url: String = "https://example.com/a1",
        title: String = "Title",
        source: NewsSource = .vnexpress,
        category: NewsCategory = .sport,
        publishedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> Article {
        Article(
            title: title, summary: "Summary", url: URL(string: url)!, imageURL: nil,
            source: source, category: category, publishedAt: publishedAt
        )
    }
}

final class MockRefreshScheduler: RefreshScheduling {
    var onTick: (() -> Void)?
    private(set) var startedInterval: TimeInterval?
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0

    func start(interval: TimeInterval) {
        startCallCount += 1
        startedInterval = interval
    }

    func stop() {
        stopCallCount += 1
    }

    func fireTick() {
        onTick?()
    }
}

/// Never asked to load anything in view model tests, which are about feed state rather than
/// images, but the view model needs something to hand to its rows.
struct StubThumbnailLoader: ThumbnailLoading {
    func thumbnail(for url: URL, maxPixelSize: Int) async throws -> UIImage {
        throw ThumbnailError.notAnImage
    }
}

extension XCTestCase {
    /// Runs `operation` and returns the error it threw, failing the test if it did not throw.
    ///
    /// Lets a test keep a single `when` that produces a value, rather than a `do`/`catch` block
    /// that performs the action and asserts about it in the same breath.
    func errorThrown(
        file: StaticString = #filePath,
        line: UInt = #line,
        from operation: () async throws -> Void
    ) async -> Error? {
        do {
            try await operation()
            XCTFail("expected an error, but none was thrown", file: file, line: line)
            return nil
        } catch {
            return error
        }
    }
}
