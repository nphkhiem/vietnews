import Factory
import Foundation

enum UITestSupport {
    static func configureIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTesting") else { return }

        struct StubArticleRepository: ArticleRepository {
            func fetchArticles(category: NewsCategory, language: Language) async throws -> FetchResult {
                let articles = (1...3).map { index in
                    Article(
                        title: "\(category.displayName(in: language)) Story \(index)",
                        summary: "Stub summary \(index)",
                        url: URL(string: "https://example.com/\(category.rawValue)/\(index)")!,
                        imageURL: nil,
                        source: .vnexpress,
                        category: category,
                        publishedAt: Date(timeIntervalSince1970: Double(index))
                    )
                }
                return FetchResult(articles: articles, failedSources: [])
            }
        }

        struct NoOpCacheRepository: CacheRepository {
            func save(_ entry: CachedArticles, category: NewsCategory, language: Language) throws {}
            func load(category: NewsCategory, language: Language) -> CachedArticles? { nil }
            func clearAll() throws {}
        }

        Container.shared.articleRepository.register { StubArticleRepository() }
        Container.shared.cacheRepository.register { NoOpCacheRepository() }
    }
}
