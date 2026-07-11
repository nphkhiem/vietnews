import Foundation

enum VNExpressSource {
    private static let vietnameseSections: [NewsCategory: String] = [
        .sport: "the-thao",
        .hotNews: "tin-moi-nhat",
        .world: "the-gioi",
        .finance: "kinh-doanh",
        .work: "doi-song",
        .technology: "khoa-hoc-cong-nghe",
        .car: "oto-xe-may",
        .social: "goc-nhin",
        .game: "khoa-hoc-cong-nghe"
    ]

    private static let englishSections: [NewsCategory: String] = [
        .sport: "sports",
        .hotNews: "news",
        .world: "world",
        .finance: "business",
        .work: "life",
        .technology: "tech",
        .car: "tech",
        .social: "life",
        .game: "tech"
    ]

    static func make(network: NetworkService, parser: RSSParsing) -> RSSFeedSource {
        RSSFeedSource(source: .vnexpress, network: network, parser: parser) { category, language in
            switch language {
            case .vietnamese:
                return vietnameseSections[category]
                    .flatMap { URL(string: "https://vnexpress.net/rss/\($0).rss") }
            case .english:
                return englishSections[category]
                    .flatMap { URL(string: "https://e.vnexpress.net/rss/\($0).rss") }
            }
        }
    }
}
