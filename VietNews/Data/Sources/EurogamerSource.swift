import Foundation

enum EurogamerSource {
    static func make(network: NetworkService, parser: RSSParsing) -> RSSFeedSource {
        RSSFeedSource(source: .eurogamer, network: network, parser: parser) { category, language in
            guard category == .game, language == .english else { return nil }
            return URL(string: "https://www.eurogamer.net/feed")
        }
    }
}
