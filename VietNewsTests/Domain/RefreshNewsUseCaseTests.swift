import XCTest
@testable import VietNews

final class RefreshNewsUseCaseTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 10_000)

    func test_givenFreshCache_whenExecuting_thenBypassesCacheAndSaves() async throws {
        let articleRepo = MockArticleRepository()
        let cacheRepo = MockCacheRepository()
        cacheRepo.stored["sport_vi"] = CachedArticles(
            articles: [TestFactory.article(url: "https://old.com/1")],
            fetchedAt: fixedNow.addingTimeInterval(-10) // fresh - must be ignored
        )
        let fresh = [TestFactory.article(url: "https://new.com/1")]
        articleRepo.result = .success(FetchResult(articles: fresh, failedSources: []))
        let sut = RefreshNewsUseCase(
            articleRepository: articleRepo, cacheRepository: cacheRepo, now: { self.fixedNow }
        )

        let result = try await sut.execute(category: .sport, language: .vietnamese)

        XCTAssertEqual(articleRepo.fetchCallCount, 1)
        XCTAssertEqual(result.articles, fresh)
        XCTAssertFalse(result.isFromCache)
        XCTAssertEqual(cacheRepo.stored["sport_vi"]?.articles, fresh)
    }

    func test_givenFetchFailure_whenExecuting_thenRethrowsError() async {
        let articleRepo = MockArticleRepository()
        articleRepo.result = .failure(NewsError.networkUnavailable)
        let sut = RefreshNewsUseCase(
            articleRepository: articleRepo, cacheRepository: MockCacheRepository()
        )

        do {
            _ = try await sut.execute(category: .sport, language: .vietnamese)
            XCTFail("Expected throw")
        } catch {
            XCTAssertEqual(error as? NewsError, .networkUnavailable)
        }
    }
}
