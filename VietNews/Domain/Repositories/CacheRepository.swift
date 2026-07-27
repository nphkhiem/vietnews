import Foundation

struct CachedArticles: Codable, Equatable {
    let articles: [Article]
    let fetchedAt: Date
    /// The maximum article count in force when this entry was written. Raising the limit means
    /// the entry can no longer satisfy the request and must be refetched; lowering it does not,
    /// because a prefix of the entry is still correct. Optional so entries written before this
    /// field existed still decode, and those are treated as unable to satisfy any limit.
    let articleLimit: Int?

    init(articles: [Article], fetchedAt: Date, articleLimit: Int? = nil) {
        self.articles = articles
        self.fetchedAt = fetchedAt
        self.articleLimit = articleLimit
    }

    func satisfies(articleLimit limit: Int) -> Bool {
        guard let articleLimit else { return false }
        return articleLimit >= limit
    }
}

protocol CacheRepository {
    func save(_ entry: CachedArticles, category: NewsCategory, language: Language) throws
    func load(category: NewsCategory, language: Language) -> CachedArticles?
    func clearAll() throws
}
