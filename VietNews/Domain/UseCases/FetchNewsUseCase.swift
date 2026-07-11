import Foundation

struct NewsFeedResult: Equatable {
    let articles: [Article]
    let failedSources: [NewsSource]
    let lastUpdated: Date
    let isFromCache: Bool
}

struct FetchNewsUseCase {
    private let articleRepository: ArticleRepository
    private let cacheRepository: CacheRepository
    private let ttl: TimeInterval
    private let now: () -> Date

    init(
        articleRepository: ArticleRepository,
        cacheRepository: CacheRepository,
        ttl: TimeInterval = 300,
        now: @escaping () -> Date = Date.init
    ) {
        self.articleRepository = articleRepository
        self.cacheRepository = cacheRepository
        self.ttl = ttl
        self.now = now
    }

    func execute(category: NewsCategory, language: Language) async throws -> NewsFeedResult {
        let cached = cacheRepository.load(category: category, language: language)

        if let cached, now().timeIntervalSince(cached.fetchedAt) < ttl {
            return NewsFeedResult(
                articles: cached.articles,
                failedSources: [],
                lastUpdated: cached.fetchedAt,
                isFromCache: true
            )
        }

        do {
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
        } catch {
            if let cached {
                return NewsFeedResult(
                    articles: cached.articles,
                    failedSources: NewsSource.allCases,
                    lastUpdated: cached.fetchedAt,
                    isFromCache: true
                )
            }
            throw error
        }
    }
}
