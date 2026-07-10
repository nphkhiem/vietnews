import Foundation
@testable import VietNews

final class MockArticleRepository: ArticleRepository {
    var result: Result<FetchResult, Error> = .success(FetchResult(articles: [], failedSources: []))
    private(set) var fetchCallCount = 0
    private(set) var lastCategory: NewsCategory?
    private(set) var lastLanguage: Language?

    func fetchArticles(category: NewsCategory, language: Language) async throws -> FetchResult {
        fetchCallCount += 1
        lastCategory = category
        lastLanguage = language
        return try result.get()
    }
}

final class MockCacheRepository: CacheRepository {
    var stored: [String: CachedArticles] = [:]
    private(set) var saveCallCount = 0
    private(set) var clearAllCallCount = 0

    private func key(_ category: NewsCategory, _ language: Language) -> String {
        "\(category.rawValue)_\(language.rawValue)"
    }

    func save(_ entry: CachedArticles, category: NewsCategory, language: Language) throws {
        saveCallCount += 1
        stored[key(category, language)] = entry
    }

    func load(category: NewsCategory, language: Language) -> CachedArticles? {
        stored[key(category, language)]
    }

    func clearAll() throws {
        clearAllCallCount += 1
        stored.removeAll()
    }
}

enum TestFactory {
    static func article(
        url: String = "https://example.com/a1",
        title: String = "Title",
        source: NewsSource = .vnexpress,
        category: NewsCategory = .sport,
        publishedAt: Date = Date(timeIntervalSince1970: 1_000)
    ) -> Article {
        Article(
            title: title, summary: "Summary", url: URL(string: url)!, imageURL: nil,
            source: source, category: category, publishedAt: publishedAt
        )
    }
}
