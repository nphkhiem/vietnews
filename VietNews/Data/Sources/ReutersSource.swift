import Foundation

enum ReutersSource {
    private static let topics: [NewsCategory: String] = [
        .sport: "sports",
        .hotNews: "top-news",
        .world: "top-news",
        .finance: "business-finance",
        .technology: "tech"
    ]

    static func make(network: NetworkService, parser: RSSParsing) -> RSSFeedSource {
        RSSFeedSource(source: .reuters, network: network, parser: parser) { category, language in
            guard language == .english, let topic = topics[category] else { return nil }
            return URL(string: "https://www.reutersagency.com/feed/?best-topics=\(topic)&post_type=best")
        }
    }
}
