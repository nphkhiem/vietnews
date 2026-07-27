import Foundation

/// Replaces Reuters, whose public RSS was retired. Every path below was verified live on
/// 2026-07-27. Note the https scheme: BBC also serves these over http, which App Transport
/// Security blocks, and the failure would be silent.
enum BBCSource {
    private static let paths: [NewsCategory: String] = [
        .hotNews: "news/rss.xml",
        .world: "news/world/rss.xml",
        .finance: "news/business/rss.xml",
        .technology: "news/technology/rss.xml",
        .sport: "sport/rss.xml"
        // .work, .car, .social, .game intentionally omitted: BBC has no equivalent topic feed,
        // and mapping them to the general news feed would duplicate .hotNews content.
    ]

    static func make(network: NetworkService, parser: RSSParsing) -> RSSFeedSource {
        RSSFeedSource(source: .bbc, network: network, parser: parser) { category, language in
            guard language == .english, let path = paths[category] else { return nil }
            return URL(string: "https://feeds.bbci.co.uk/\(path)")
        }
    }
}
