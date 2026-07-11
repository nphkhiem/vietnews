import Foundation

struct CachedArticles: Codable, Equatable {
    let articles: [Article]
    let fetchedAt: Date
}

protocol CacheRepository {
    func save(_ entry: CachedArticles, category: NewsCategory, language: Language) throws
    func load(category: NewsCategory, language: Language) -> CachedArticles?
    func clearAll() throws
}
