import Foundation

struct SubstackFeed: Codable, Equatable {
    let url: URL
    let category: NewsCategory
}

struct SubstackSource: NewsSourceAdapter {
    let source: NewsSource = .substack
    private let network: NetworkService
    private let parser: RSSParsing
    private let feeds: () -> [SubstackFeed]
    private let health: SourceHealthRepository?

    init(
        network: NetworkService,
        parser: RSSParsing,
        feeds: @escaping () -> [SubstackFeed],
        health: SourceHealthRepository? = nil
    ) {
        self.network = network
        self.parser = parser
        self.feeds = feeds
        self.health = health
    }

    func supports(category: NewsCategory, language: Language) -> Bool {
        !endpoints(category: category, language: language).isEmpty
    }

    /// Excludes feeds the reader switched off, so a category served only by disabled feeds
    /// reports that it has nothing to serve rather than being attempted and failing.
    func endpoints(category: NewsCategory, language: Language) -> [URL] {
        feeds()
            .filter { $0.category == category }
            .filter { health?.isEnabled(.userFeed($0.url)) ?? true }
            .map(\.url)
    }

    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        let urls = endpoints(category: category, language: language)
        let health = self.health
        let parser = self.parser
        let network = self.network

        return await withTaskGroup(of: [Article].self) { group in
            for url in urls {
                group.addTask {
                    // Each feed is recorded separately. One adapter serves all of them, so a
                    // single `.substack` verdict could not say which feed is broken, and the
                    // errors used to be swallowed here entirely.
                    let identity = SourceIdentity.userFeed(url)
                    let data: Data
                    do {
                        data = try await network.data(from: url)
                    } catch {
                        health?.recordFailure(identity, cause: SourceFailureCause(error))
                        return []
                    }

                    guard let items = try? parser.parse(data) else {
                        health?.recordFailure(identity, cause: .unparseable)
                        return []
                    }

                    // The publication's own name, read once and then remembered, so the cost is
                    // a second parse the first time a feed ever succeeds and nothing after that.
                    let title = health?.health(for: identity).publicationTitle
                        ?? parser.channelTitle(in: data)
                    health?.recordSuccess(identity, at: Date(), publicationTitle: title)

                    return items.map { item in
                        Article(
                            title: item.title,
                            summary: item.summary,
                            url: item.link,
                            imageURL: item.imageURL,
                            source: .substack,
                            category: category,
                            publishedAt: item.publishedAt
                        )
                    }
                }
            }
            var all: [Article] = []
            for await batch in group { all.append(contentsOf: batch) }
            return all
        }
    }
}
