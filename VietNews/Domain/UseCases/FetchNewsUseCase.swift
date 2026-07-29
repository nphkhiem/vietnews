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
    private let ttl: () -> TimeInterval
    private let now: () -> Date
    private let articleLimit: () -> Int

    init(
        articleRepository: ArticleRepository,
        cacheRepository: CacheRepository,
        ttl: @escaping () -> TimeInterval = { 300 },
        now: @escaping () -> Date = Date.init,
        articleLimit: @escaping () -> Int = { 15 }
    ) {
        self.articleRepository = articleRepository
        self.cacheRepository = cacheRepository
        self.ttl = ttl
        self.now = now
        self.articleLimit = articleLimit
    }

    /// Only `allSourcesFailed` knows which sources were actually attempted. Any other failure
    /// names none, rather than implicating sources that were never part of the request.
    private static func failedSources(from error: Error) -> [NewsSource] {
        guard case .allSourcesFailed(let sources, _) = error as? NewsError else { return [] }
        return sources
    }

    func execute(category: NewsCategory, language: Language) async throws -> NewsFeedResult {
        let cached = cacheRepository.load(category: category, language: language)
        let limit = articleLimit()

        if let cached, now().timeIntervalSince(cached.fetchedAt) < ttl(), cached.satisfies(articleLimit: limit) {
            return NewsFeedResult(
                articles: cached.articles,
                failedSources: cached.failedSources,
                lastUpdated: cached.fetchedAt,
                isFromCache: true
            )
        }

        do {
            let fetched = try await articleRepository.fetchArticles(category: category, language: language)
            let fetchedAt = now()
            try? cacheRepository.save(
                CachedArticles(
                    articles: fetched.articles,
                    fetchedAt: fetchedAt,
                    articleLimit: limit,
                    failedSources: fetched.failedSources
                ),
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
                    failedSources: Self.failedSources(from: error),
                    lastUpdated: cached.fetchedAt,
                    isFromCache: true
                )
            }
            throw error
        }
    }
}
