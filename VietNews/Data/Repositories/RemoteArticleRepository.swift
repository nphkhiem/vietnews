import Foundation

final class RemoteArticleRepository: ArticleRepository {
    private let adapters: [NewsSourceAdapter]
    private let perSourceTimeout: TimeInterval
    private let maxArticles: () -> Int
    private let maxSourceShare: Double
    private let health: SourceHealthRepository?

    init(
        adapters: [NewsSourceAdapter],
        perSourceTimeout: TimeInterval = 10,
        maxArticles: @escaping () -> Int = { 15 },
        maxSourceShare: Double = 1.0 / 3.0,
        health: SourceHealthRepository? = nil
    ) {
        self.adapters = adapters
        self.perSourceTimeout = perSourceTimeout
        self.maxArticles = maxArticles
        self.maxSourceShare = maxSourceShare
        self.health = health
    }

    func fetchArticles(category: NewsCategory, language: Language) async throws -> FetchResult {
        let health = self.health
        // A source the reader switched off is never attempted, which is also what stops it
        // contributing failures: it cannot appear in `failedSources` if it was never asked.
        let applicable = adapters
            .filter { health?.isEnabled(.builtIn($0.source)) ?? true }
            .filter { $0.supports(category: category, language: language) }
        guard !applicable.isEmpty else {
            return FetchResult(articles: [], failedSources: [])
        }

        let timeout = perSourceTimeout
        let outcomes = await withTaskGroup(
            of: (NewsSource, Result<[Article], Error>).self
        ) { group -> [(NewsSource, Result<[Article], Error>)] in
            for adapter in applicable {
                group.addTask {
                    do {
                        let articles = try await Self.withTimeout(seconds: timeout, source: adapter.source) {
                            try await adapter.fetch(category: category, language: language)
                        }
                        return (adapter.source, .success(articles))
                    } catch {
                        return (adapter.source, .failure(error))
                    }
                }
            }
            var collected: [(NewsSource, Result<[Article], Error>)] = []
            for await outcome in group { collected.append(outcome) }
            return collected
        }

        var articlesBySource: [[Article]] = []
        var failedSources: [NewsSource] = []
        var failures: [Error] = []
        let now = Date()
        for (source, outcome) in outcomes {
            switch outcome {
            case .success(let articles):
                articlesBySource.append(articles)
                health?.recordSuccess(.builtIn(source), at: now, publicationTitle: nil)
            case .failure(let error):
                failedSources.append(source)
                failures.append(error)
                health?.recordFailure(.builtIn(source), cause: SourceFailureCause(error))
            }
        }

        guard failedSources.count < applicable.count else {
            throw NewsError.allSourcesFailed(failedSources, cause: Self.cause(of: failures))
        }

        let merged = articlesBySource
            .flatMap { $0 }
            // Undated articles sort last: they cannot be placed on the timeline, and putting
            // them first would push real news down.
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

        return FetchResult(
            articles: Self.balanced(
                Self.deduplicated(merged),
                limit: maxArticles(),
                maxSourceShare: maxSourceShare
            ),
            failedSources: failedSources
        )
    }

    /// Stops one publisher from filling a category.
    ///
    /// An aggregator whose feed renders as a single publication is not doing the thing it exists
    /// to do, and that is what pure recency produced: BBC publishes far more often than the
    /// others, so it took nearly every slot in the English categories.
    ///
    /// A source is held to its share only while other sources can fill the gap. When they cannot,
    /// the remainder is backfilled rather than leaving the category short, so a category served
    /// by a single source is unaffected. The result is re-sorted, so the cap decides which
    /// articles appear and never what order they appear in.
    private static func balanced(
        _ articles: [Article],
        limit: Int,
        maxSourceShare: Double
    ) -> [Article] {
        guard limit > 0 else { return [] }
        let perSource = max(1, Int((Double(limit) * maxSourceShare).rounded(.down)))

        var counts: [NewsSource: Int] = [:]
        var kept: [Article] = []
        var overflow: [Article] = []

        for article in articles where kept.count < limit {
            let used = counts[article.source, default: 0]
            if used < perSource {
                counts[article.source] = used + 1
                kept.append(article)
            } else {
                overflow.append(article)
            }
        }

        if kept.count < limit {
            kept.append(contentsOf: overflow.prefix(limit - kept.count))
        }

        return kept.sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }
    }

    /// Removes articles sharing an identifier, keeping the first.
    ///
    /// An article is identified by its URL, and publishers do reissue a story under a new
    /// headline at the same address: BBC did exactly that with one story appearing twice, once
    /// as "Uefa reacts with fury to Infantino World Cup plan" and once as "Uefa says Fifa plan
    /// for private investment in World Cup 'crosses line'". Two entries then carry one
    /// identifier, and a SwiftUI list given duplicate identifiers renders one of them as an
    /// empty row. Keeping the first preserves the newest, because this runs after sorting.
    private static func deduplicated(_ articles: [Article]) -> [Article] {
        var seen = Set<String>()
        return articles.filter { seen.insert($0.id).inserted }
    }

    /// Collapses per-source errors into one cause. Sources rarely fail for different reasons at
    /// once, and when they do, saying so is more honest than picking a winner.
    private static func cause(of failures: [Error]) -> SourceFailureCause {
        let causes = Set(failures.map(SourceFailureCause.init))
        guard causes.count == 1, let only = causes.first else { return .mixed }
        return only
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
