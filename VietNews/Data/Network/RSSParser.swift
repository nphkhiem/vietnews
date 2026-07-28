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

            return RSSItemDTO(
                title: title,
                link: link,
                summary: rawDescription.strippingHTML(),
                imageURL: Self.imageURL(for: item, description: rawDescription),
                publishedAt: item.pubDate
            )
        }
    }

    /// Picks the best image an item offers.
    ///
    /// Only the last two of these were read before. Measured coverage looked bimodal as a
    /// result: VNExpress and NYT supplied an image for every article and BBC supplied none,
    /// which read as a property of BBC's feed. It was not. BBC publishes `media:thumbnail` on
    /// every item and Eurogamer publishes `media:content`, and neither was being looked at.
    ///
    /// Where several are offered the widest is taken rather than the first, because feeds list
    /// them in no reliable order and the widest is the one that survives being shown as a lead.
    private static func imageURL(for item: RSSFeedItem, description: String) -> URL? {
        widestMediaContent(in: item)
            ?? widestThumbnail(in: item)
            ?? item.enclosure?.attributes?.url.flatMap(URL.init(string:))
            ?? description.firstImageURL()
    }

    private static func widestMediaContent(in item: RSSFeedItem) -> URL? {
        let contents = (item.media?.mediaContents ?? [])
            + (item.media?.mediaGroup?.mediaContents ?? [])

        return contents
            .filter(isImage)
            .max { ($0.attributes?.width ?? 0) < ($1.attributes?.width ?? 0) }?
            .attributes?.url
            .flatMap(URL.init(string:))
    }

    /// A `media:content` element can describe video or audio just as easily as an image, so it
    /// is only usable when it says which it is.
    private static func isImage(_ content: MediaContent) -> Bool {
        guard let attributes = content.attributes else { return false }
        if let medium = attributes.medium {
            return medium.lowercased() == "image"
        }
        if let type = attributes.type {
            return type.lowercased().hasPrefix("image/")
        }
        return false
    }

    private static func widestThumbnail(in item: RSSFeedItem) -> URL? {
        let grouped = item.media?.mediaGroup?.mediaContents?
            .compactMap(\.mediaThumbnails)
            .flatMap { $0 } ?? []
        let thumbnails = (item.media?.mediaThumbnails ?? []) + grouped

        return thumbnails
            .max { width(of: $0) < width(of: $1) }?
            .attributes?.url
            .flatMap(URL.init(string:))
    }

    /// `media:thumbnail` carries its width as a string, and an absent or unparseable one sorts
    /// last rather than being treated as an error.
    private static func width(of thumbnail: MediaThumbnail) -> Int {
        Int(thumbnail.attributes?.width ?? "") ?? 0
    }
}
