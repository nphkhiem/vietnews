import FeedKit
import Foundation

protocol RSSParsing {
    func parse(_ data: Data) throws -> [RSSItemDTO]
}

final class FeedKitRSSParser: RSSParsing {
    private let parsingSource: NewsSource

    init(parsingSource: NewsSource = .vnexpress) {
        self.parsingSource = parsingSource
    }

    func parse(_ data: Data) throws -> [RSSItemDTO] {
        let result = FeedParser(data: data).parse()
        guard case .success(.rss(let feed)) = result, let items = feed.items else {
            throw NewsError.parsingFailed(parsingSource)
        }
        return items.compactMap { item in
            guard
                let title = item.title?.strippingHTML(),
                let linkString = item.link,
                let link = URL(string: linkString)
            else { return nil }

            let rawDescription = item.description ?? ""
            let imageURL = item.enclosure?.attributes?.url.flatMap(URL.init(string:))
                ?? rawDescription.firstImageURL()

            return RSSItemDTO(
                title: title,
                link: link,
                summary: rawDescription.strippingHTML(),
                imageURL: imageURL,
                publishedAt: item.pubDate
            )
        }
    }
}
