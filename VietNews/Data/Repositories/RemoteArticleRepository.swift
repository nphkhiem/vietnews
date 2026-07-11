import Foundation

final class RemoteArticleRepository: ArticleRepository {
    private let adapters: [NewsSourceAdapter]
    private let perSourceTimeout: TimeInterval
    private let maxArticles: () -> Int

    init(
        adapters: [NewsSourceAdapter],
        perSourceTimeout: TimeInterval = 10,
        maxArticles: @escaping () -> Int = { 15 }
    ) {
        self.adapters = adapters
        self.perSourceTimeout = perSourceTimeout
        self.maxArticles = maxArticles
    }

    func fetchArticles(category: NewsCategory, language: Language) async throws -> FetchResult {
        let applicable = adapters.filter { $0.supports(category: category, language: language) }
        guard !applicable.isEmpty else {
            return FetchResult(articles: [], failedSources: [])
        }

        let timeout = perSourceTimeout
        let outcomes = await withTaskGroup(
            of: (NewsSource, [Article]?).self
        ) { group -> [(NewsSource, [Article]?)] in
            for adapter in applicable {
                group.addTask {
                    let articles = try? await Self.withTimeout(seconds: timeout, source: adapter.source) {
                        try await adapter.fetch(category: category, language: language)
                    }
                    return (adapter.source, articles)
                }
            }
            var collected: [(NewsSource, [Article]?)] = []
            for await outcome in group { collected.append(outcome) }
            return collected
        }

        let failedSources = outcomes.filter { $0.1 == nil }.map(\.0)
        guard failedSources.count < applicable.count else {
            throw NewsError.networkUnavailable
        }

        let merged = outcomes
            .compactMap(\.1)
            .flatMap { $0 }
            .sorted { $0.publishedAt > $1.publishedAt }
        return FetchResult(articles: Array(merged.prefix(maxArticles())), failedSources: failedSources)
    }

    private static func withTimeout<T: Sendable>(
        seconds: TimeInterval,
        source: NewsSource,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NewsError.sourceTimeout(source)
            }
            guard let first = try await group.next() else {
                throw NewsError.sourceTimeout(source)
            }
            group.cancelAll()
            return first
        }
    }
}
