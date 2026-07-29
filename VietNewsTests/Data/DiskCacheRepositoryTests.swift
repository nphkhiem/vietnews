import XCTest
@testable import VietNews

final class DiskCacheRepositoryTests: XCTestCase {
    private var tempDir: URL!
    private var sut: DiskCacheRepository!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        sut = DiskCacheRepository(directory: tempDir)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        try super.tearDownWithError()
    }

    private func entry(at epoch: TimeInterval = 1_000) -> CachedArticles {
        CachedArticles(
            articles: [TestFactory.article()],
            fetchedAt: Date(timeIntervalSince1970: epoch)
        )
    }

    /// A source can be retired between releases, leaving cached articles that name a case the
    /// app no longer has. Loading must degrade to a cache miss and refetch, never trap.
    func test_givenCachedArticleFromRetiredSource_whenLoading_thenReturnsNilInsteadOfCrashing() throws {
        // given
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let stale = """
        {"fetchedAt": 1000, "articles": [{
            "id": "https://example.com/a",
            "title": "Retired source article",
            "summary": "",
            "url": "https://example.com/a",
            "source": "reuters",
            "category": "world",
            "publishedAt": 900
        }]}
        """

        try Data(stale.utf8).write(to: tempDir.appendingPathComponent("world_en.json"))

        // when
        let entry = sut.load(category: .world, language: .english)

        // then
        XCTAssertNil(entry)
    }

    func test_givenSavedEntry_whenLoading_thenReturnsSameEntry() throws {
        // given
        let saved = entry()
        try sut.save(saved, category: .sport, language: .vietnamese)

        // when
        let loaded = sut.load(category: .sport, language: .vietnamese)

        // then
        XCTAssertEqual(loaded, saved)
    }

    func test_givenNoSavedEntry_whenLoading_thenReturnsNil() {
        // given
        // Nothing saved: the suite uses a fresh directory per test.

        // when
        let entry = sut.load(category: .world, language: .english)

        // then
        XCTAssertNil(entry)
    }

    func test_givenEntriesForDifferentCategoriesAndLanguages_whenLoading_thenEachIsIsolated() throws {
        // given
        try sut.save(entry(at: 1), category: .sport, language: .vietnamese)

        // when
        try sut.save(entry(at: 2), category: .sport, language: .english)

        // then
        XCTAssertEqual(sut.load(category: .sport, language: .vietnamese)?.fetchedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(sut.load(category: .sport, language: .english)?.fetchedAt, Date(timeIntervalSince1970: 2))
        XCTAssertNil(sut.load(category: .world, language: .vietnamese))
    }

    func test_givenSavedEntries_whenClearingAll_thenAllEntriesRemoved() throws {
        // given
        try sut.save(entry(), category: .sport, language: .vietnamese)
        try sut.save(entry(), category: .world, language: .english)

        // when
        try sut.clearAll()

        // then
        XCTAssertNil(sut.load(category: .sport, language: .vietnamese))
        XCTAssertNil(sut.load(category: .world, language: .english))
    }

    func test_givenExistingEntry_whenSavingNewEntry_thenOverwritesPrevious() throws {
        // given
        try sut.save(entry(at: 1), category: .sport, language: .vietnamese)

        // when
        try sut.save(entry(at: 2), category: .sport, language: .vietnamese)

        // then
        XCTAssertEqual(
            sut.load(category: .sport, language: .vietnamese)?.fetchedAt,
            Date(timeIntervalSince1970: 2)
        )
    }

    func test_givenCorruptCacheFile_whenLoading_thenReturnsNil() throws {
        // given
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        // when
        try Data("not json".utf8).write(to: tempDir.appendingPathComponent("sport_vi.json"))

        // then
        XCTAssertNil(sut.load(category: .sport, language: .vietnamese))
    }
}
