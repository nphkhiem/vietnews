import Foundation

struct CachedArticles: Codable, Equatable {
    let articles: [Article]
    let fetchedAt: Date
    /// The maximum article count in force when this entry was written. Raising the limit means
    /// the entry can no longer satisfy the request and must be refetched; lowering it does not,
    /// because a prefix of the entry is still correct. Optional so entries written before this
    /// field existed still decode, and those are treated as unable to satisfy any limit.
    let articleLimit: Int?
    /// Sources that failed when this entry was written. Serving the entry later must report the
    /// same failures, otherwise a cache hit silently claims everything worked.
    let failedSources: [NewsSource]

    init(
        articles: [Article],
        fetchedAt: Date,
        articleLimit: Int? = nil,
        failedSources: [NewsSource] = []
    ) {
        self.articles = articles
        self.fetchedAt = fetchedAt
        self.articleLimit = articleLimit
        self.failedSources = failedSources
    }

    enum CodingKeys: String, CodingKey {
        case articles, fetchedAt, articleLimit, failedSources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        articles = try container.decode([Article].self, forKey: .articles)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        articleLimit = try container.decodeIfPresent(Int.self, forKey: .articleLimit)
        failedSources = try container.decodeIfPresent([NewsSource].self, forKey: .failedSources) ?? []
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
