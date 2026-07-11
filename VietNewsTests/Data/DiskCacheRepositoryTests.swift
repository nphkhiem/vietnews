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

    func test_givenSavedEntry_whenLoading_thenReturnsSameEntry() throws {
        let saved = entry()
        try sut.save(saved, category: .sport, language: .vietnamese)

        let loaded = sut.load(category: .sport, language: .vietnamese)

        XCTAssertEqual(loaded, saved)
    }

    func test_givenNoSavedEntry_whenLoading_thenReturnsNil() {
        XCTAssertNil(sut.load(category: .world, language: .english))
    }

    func test_givenEntriesForDifferentCategoriesAndLanguages_whenLoading_thenEachIsIsolated() throws {
        try sut.save(entry(at: 1), category: .sport, language: .vietnamese)
        try sut.save(entry(at: 2), category: .sport, language: .english)

        XCTAssertEqual(sut.load(category: .sport, language: .vietnamese)?.fetchedAt, Date(timeIntervalSince1970: 1))
        XCTAssertEqual(sut.load(category: .sport, language: .english)?.fetchedAt, Date(timeIntervalSince1970: 2))
        XCTAssertNil(sut.load(category: .world, language: .vietnamese))
    }

    func test_givenSavedEntries_whenClearingAll_thenAllEntriesRemoved() throws {
        try sut.save(entry(), category: .sport, language: .vietnamese)
        try sut.save(entry(), category: .world, language: .english)

        try sut.clearAll()

        XCTAssertNil(sut.load(category: .sport, language: .vietnamese))
        XCTAssertNil(sut.load(category: .world, language: .english))
    }

    func test_givenExistingEntry_whenSavingNewEntry_thenOverwritesPrevious() throws {
        try sut.save(entry(at: 1), category: .sport, language: .vietnamese)
        try sut.save(entry(at: 2), category: .sport, language: .vietnamese)

        XCTAssertEqual(
            sut.load(category: .sport, language: .vietnamese)?.fetchedAt,
            Date(timeIntervalSince1970: 2)
        )
    }

    func test_givenCorruptCacheFile_whenLoading_thenReturnsNil() throws {
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: tempDir.appendingPathComponent("sport_vi.json"))

        XCTAssertNil(sut.load(category: .sport, language: .vietnamese))
    }
}
