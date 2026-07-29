import Foundation

struct CachedArticles: Codable, Equatable {
    /// Raised whenever the shape of what is stored changes in a way an older entry cannot
    /// satisfy. Entries written under a different version are discarded on read, deliberately,
    /// rather than being half-decoded into something that looks plausible and is not.
    static let currentSchemaVersion = 1

    /// Optional so entries written before versioning existed still decode; those are treated as
    /// version zero and therefore stale.
    let schemaVersion: Int?
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
        failedSources: [NewsSource] = [],
        schemaVersion: Int? = CachedArticles.currentSchemaVersion
    ) {
        self.articles = articles
        self.fetchedAt = fetchedAt
        self.articleLimit = articleLimit
        self.failedSources = failedSources
        self.schemaVersion = schemaVersion
    }

    enum CodingKeys: String, CodingKey {
        case articles, fetchedAt, articleLimit, failedSources, schemaVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        articles = try container.decode([Article].self, forKey: .articles)
        fetchedAt = try container.decode(Date.self, forKey: .fetchedAt)
        articleLimit = try container.decodeIfPresent(Int.self, forKey: .articleLimit)
        failedSources = try container.decodeIfPresent([NewsSource].self, forKey: .failedSources) ?? []
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion)
    }

    var matchesCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
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
    /// Bytes currently held on disk. The cache existed for months with no way for a reader to
    /// see it or clear it.
    func totalSizeInBytes() -> Int
}
