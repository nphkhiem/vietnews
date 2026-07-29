import XCTest
@testable import VietNews

final class RefreshNewsUseCaseTests: XCTestCase {
    private let fixedNow = Date(timeIntervalSince1970: 10_000)

    func test_givenFreshCache_whenExecuting_thenBypassesCacheAndSaves() async throws {
        // given
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

        // when
        let result = try await sut.execute(category: .sport, language: .vietnamese)

        // then
        XCTAssertEqual(articleRepo.fetchCallCount, 1)
        XCTAssertEqual(result.articles, fresh)
        XCTAssertFalse(result.isFromCache)
        XCTAssertEqual(cacheRepo.stored["sport_vi"]?.articles, fresh)
    }

    func test_givenFetchFailure_whenExecuting_thenRethrowsError() async {
        // given
        let articleRepo = MockArticleRepository()
        articleRepo.result = .failure(NewsError.networkUnavailable)
        let sut = RefreshNewsUseCase(
            articleRepository: articleRepo, cacheRepository: MockCacheRepository()
        )

        // when
        let thrown = await errorThrown {
            _ = try await sut.execute(category: .sport, language: .vietnamese)
        }

        // then
        XCTAssertEqual(thrown as? NewsError, .networkUnavailable)
    }
}
