import Foundation

struct RefreshNewsUseCase {
    private let articleRepository: ArticleRepository
    private let cacheRepository: CacheRepository
    private let now: () -> Date

    init(
        articleRepository: ArticleRepository,
        cacheRepository: CacheRepository,
        now: @escaping () -> Date = Date.init
    ) {
        self.articleRepository = articleRepository
        self.cacheRepository = cacheRepository
        self.now = now
    }

    func execute(category: NewsCategory, language: Language) async throws -> NewsFeedResult {
        let fetched = try await articleRepository.fetchArticles(category: category, language: language)
        let fetchedAt = now()
        try? cacheRepository.save(
            CachedArticles(articles: fetched.articles, fetchedAt: fetchedAt),
            category: category,
            language: language
        )
        return NewsFeedResult(
            articles: fetched.articles,
            failedSources: fetched.failedSources,
            lastUpdated: fetchedAt,
            isFromCache: false
        )
    }
}
