import Foundation

struct RSSFeedSource: NewsSourceAdapter {
    let source: NewsSource
    private let network: NetworkService
    private let parser: RSSParsing
    private let feedURL: (NewsCategory, Language) -> URL?

    init(
        source: NewsSource,
        network: NetworkService,
        parser: RSSParsing,
        feedURL: @escaping (NewsCategory, Language) -> URL?
    ) {
        self.source = source
        self.network = network
        self.parser = parser
        self.feedURL = feedURL
    }

    func supports(category: NewsCategory, language: Language) -> Bool {
        feedURL(category, language) != nil
    }

    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        guard let url = feedURL(category, language) else { return [] }
        let data = try await network.data(from: url)
        return try parser.parse(data).map { item in
            Article(
                title: item.title,
                summary: item.summary,
                url: item.link,
                imageURL: item.imageURL,
                source: source,
                category: category,
                publishedAt: item.publishedAt ?? .distantPast
            )
        }
    }
}
