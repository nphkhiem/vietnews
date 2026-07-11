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

    init(
        network: NetworkService,
        parser: RSSParsing,
        feeds: @escaping () -> [SubstackFeed]
    ) {
        self.network = network
        self.parser = parser
        self.feeds = feeds
    }

    func supports(category: NewsCategory, language: Language) -> Bool {
        feeds().contains { $0.category == category }
    }

    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        let urls = feeds().filter { $0.category == category }.map(\.url)
        return await withTaskGroup(of: [Article].self) { group in
            for url in urls {
                group.addTask {
                    guard let data = try? await network.data(from: url),
                          let items = try? parser.parse(data) else { return [] }
                    return items.map { item in
                        Article(
                            title: item.title,
                            summary: item.summary,
                            url: item.link,
                            imageURL: item.imageURL,
                            source: .substack,
                            category: category,
                            publishedAt: item.publishedAt ?? .distantPast
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
