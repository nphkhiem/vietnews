import XCTest
@testable import VietNews

final class CacheHardeningTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CacheHardeningTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
        try super.tearDownWithError()
    }

    private func entry(articles: Int = 1, schemaVersion: Int? = CachedArticles.currentSchemaVersion) -> CachedArticles {
        CachedArticles(
            articles: (0..<articles).map { TestFactory.article(url: "https://example.com/\($0)") },
            fetchedAt: Date(timeIntervalSince1970: 1_000),
            articleLimit: 15,
            failedSources: [],
            schemaVersion: schemaVersion
        )
    }

    func test_givenAnEntryWrittenNow_whenLoaded_thenItIsServed() throws {
        let sut = DiskCacheRepository(directory: directory)
        try sut.save(entry(), category: .sport, language: .english)

        XCTAssertNotNil(sut.load(category: .sport, language: .english))
    }

    /// Decoding succeeding is not the same as the entry meaning what this version thinks it
    /// means. A plausible wrong answer is worse than a refetch.
    func test_givenAnEntryFromAnotherSchema_whenLoaded_thenItIsDiscarded() throws {
        let sut = DiskCacheRepository(directory: directory)
        try sut.save(entry(schemaVersion: 99), category: .sport, language: .english)

        XCTAssertNil(sut.load(category: .sport, language: .english))
    }

    /// Entries written before versioning existed decode fine and are still stale.
    func test_givenAnEntryFromBeforeVersioning_whenLoaded_thenItIsDiscarded() throws {
        let sut = DiskCacheRepository(directory: directory)
        try sut.save(entry(schemaVersion: nil), category: .sport, language: .english)

        XCTAssertNil(sut.load(category: .sport, language: .english))
    }

    func test_givenADiscardedEntry_whenLoadedAgain_thenTheFileIsGone() throws {
        let sut = DiskCacheRepository(directory: directory)
        try sut.save(entry(schemaVersion: 99), category: .sport, language: .english)

        _ = sut.load(category: .sport, language: .english)

        XCTAssertEqual(sut.totalSizeInBytes(), 0)
    }

    /// A cache that only grew was the one part of the app that could not be reclaimed.
    func test_givenMoreThanTheSizeLimit_whenSaving_thenItEvictsDownToIt() throws {
        // Small enough that a couple of entries exceed it, so eviction is exercised rather than
        // assumed.
        let sut = DiskCacheRepository(directory: directory, sizeLimitInBytes: 2_000)

        for category in [NewsCategory.sport, .world, .finance, .technology] {
            try sut.save(entry(articles: 12), category: category, language: .english)
        }

        XCTAssertLessThanOrEqual(sut.totalSizeInBytes(), 2_000)
    }

    /// The entry just written is never the one evicted to make room for itself.
    func test_givenEvictionRuns_whenItFinishes_thenTheNewestEntrySurvives() throws {
        let sut = DiskCacheRepository(directory: directory, sizeLimitInBytes: 2_000)
        for category in [NewsCategory.sport, .world, .finance] {
            try sut.save(entry(articles: 12), category: category, language: .english)
        }

        try sut.save(entry(articles: 1), category: .technology, language: .english)

        XCTAssertNotNil(sut.load(category: .technology, language: .english))
    }

    func test_givenTheDefaultDirectory_whenAsked_thenItResolvesWithoutCrashing() {
        XCTAssertTrue(DiskCacheRepository.defaultDirectory().path.hasSuffix("articles"))
    }
}
