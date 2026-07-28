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
        for (source, outcome) in outcomes {
            switch outcome {
            case .success(let articles):
                articlesBySource.append(articles)
            case .failure(let error):
                failedSources.append(source)
                failures.append(error)
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
            articles: Array(Self.deduplicated(merged).prefix(maxArticles())),
            failedSources: failedSources
        )
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
        let causes = Set(failures.map(classify))
        guard causes.count == 1, let only = causes.first else { return .mixed }
        return only
    }

    private static func classify(_ error: Error) -> SourceFailureCause {
        switch error {
        case let newsError as NewsError:
            switch newsError {
            case .sourceTimeout: return .timedOut
            case .invalidResponse: return .rejected
            case .rateLimited: return .rateLimited
            case .parsingFailed: return .unparseable
            case .networkUnavailable: return .unreachable
            case .allSourcesFailed(_, let cause): return cause
            case .cacheFailed: return .mixed
            }
        case let urlError as URLError:
            switch urlError.code {
            case .timedOut: return .timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                return .unreachable
            default: return .mixed
            }
        default:
            return .mixed
        }
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
