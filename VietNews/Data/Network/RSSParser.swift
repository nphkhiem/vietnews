import FeedKit
import Foundation

protocol RSSParsing {
    func parse(_ data: Data) throws -> [RSSItemDTO]
    /// The channel's own name, so a feed the reader added is listed as its publication rather
    /// than as a hostname. Kept off `parse` because only the sources screen wants it, and it is
    /// read once per feed and then remembered.
    func channelTitle(in data: Data) -> String?
}

extension RSSParsing {
    func channelTitle(in data: Data) -> String? { nil }
}

/// Reads the three feed formats the app claims to accept.
///
/// Only RSS was ever read. Anything else fell through a `guard case .success(.rss(...))` and was
/// discarded as a parse failure, while the README advertised Atom and the settings screen invited
/// any feed address at all. A reader who added an Atom feed got an empty source and no reason.
final class FeedKitRSSParser: RSSParsing {
    private let parsingSource: NewsSource

    init(parsingSource: NewsSource = .vnexpress) {
        self.parsingSource = parsingSource
    }

    func parse(_ data: Data) throws -> [RSSItemDTO] {
        switch FeedParser(data: data).parse() {
        case .success(.rss(let feed)):
            return (feed.items ?? []).compactMap(Self.item(from:))
        case .success(.atom(let feed)):
            return (feed.entries ?? []).compactMap(Self.item(from:))
        case .success(.json(let feed)):
            return (feed.items ?? []).compactMap(Self.item(from:))
        case .failure:
            throw NewsError.parsingFailed(parsingSource)
        }
    }

    func channelTitle(in data: Data) -> String? {
        let title: String?
        switch FeedParser(data: data).parse() {
        case .success(.rss(let feed)): title = feed.title
        case .success(.atom(let feed)): title = feed.title
        case .success(.json(let feed)): title = feed.title
        case .failure: return nil
        }
        let cleaned = title?.strippingHTML().trimmingCharacters(in: .whitespacesAndNewlines)
        return (cleaned?.isEmpty ?? true) ? nil : cleaned
    }

    // MARK: - RSS

    private static func item(from item: RSSFeedItem) -> RSSItemDTO? {
        guard
            let title = item.title?.strippingHTML(),
            let link = item.link.flatMap(URL.init(string:))
        else { return nil }

        let rawDescription = item.description ?? ""

        return RSSItemDTO(
            title: title,
            link: link,
            summary: rawDescription.strippingHTML(),
            imageURL: imageURL(for: item, description: rawDescription),
            publishedAt: item.pubDate
        )
    }

    // MARK: - Atom

    private static func item(from entry: AtomFeedEntry) -> RSSItemDTO? {
        guard
            let title = entry.title?.strippingHTML(),
            let link = link(in: entry)
        else { return nil }

        // Atom entries carry a short `summary`, a full `content`, or both. The summary is what
        // this app shows, so it wins; content is the fallback rather than the other way round.
        let rawSummary = entry.summary?.value ?? entry.content?.value ?? ""

        return RSSItemDTO(
            title: title,
            link: link,
            summary: rawSummary.strippingHTML(),
            imageURL: mediaImageURL(in: entry.media) ?? rawSummary.firstImageURL(),
            // `published` is when it was written and `updated` is mandatory. Preferring
            // `published` keeps a lightly edited old entry from resurfacing as new.
            publishedAt: entry.published ?? entry.updated
        )
    }

    /// An entry lists several links: alternates, enclosures, the entry's own canonical address.
    /// The alternate is the one a reader should be sent to, and `rel` is optional and defaults to
    /// alternate, so an absent one counts.
    private static func link(in entry: AtomFeedEntry) -> URL? {
        let links = entry.links ?? []
        let alternate = links.first { link in
            let rel = link.attributes?.rel
            return rel == nil || rel == "alternate"
        }
        return (alternate ?? links.first)?.attributes?.href.flatMap(URL.init(string:))
    }

    // MARK: - JSON

    private static func item(from item: JSONFeedItem) -> RSSItemDTO? {
        guard let link = (item.url ?? item.externalUrl).flatMap(URL.init(string:)) else {
            return nil
        }

        let rawSummary = item.summary ?? item.contentText ?? item.contentHtml ?? ""
        // A JSON feed item may legitimately have no title, in which case its text stands in for
        // one. An untitled, textless item is not an article and is dropped.
        let title = item.title?.strippingHTML() ?? rawSummary.strippingHTML()
        guard !title.isEmpty else { return nil }

        return RSSItemDTO(
            title: title,
            link: link,
            summary: item.title == nil ? "" : rawSummary.strippingHTML(),
            imageURL: (item.image ?? item.bannerImage).flatMap(URL.init(string:))
                ?? (item.contentHtml ?? "").firstImageURL(),
            publishedAt: item.datePublished
        )
    }

    // MARK: - Images

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
        mediaImageURL(in: item.media)
            ?? item.enclosure?.attributes?.url.flatMap(URL.init(string:))
            ?? description.firstImageURL()
    }

    /// The `media:` namespace is shared by RSS and Atom, so both read it the same way.
    private static func mediaImageURL(in media: MediaNamespace?) -> URL? {
        widestMediaContent(in: media) ?? widestThumbnail(in: media)
    }

    private static func widestMediaContent(in media: MediaNamespace?) -> URL? {
        let contents = (media?.mediaContents ?? []) + (media?.mediaGroup?.mediaContents ?? [])

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

    private static func widestThumbnail(in media: MediaNamespace?) -> URL? {
        let grouped = media?.mediaGroup?.mediaContents?
            .compactMap(\.mediaThumbnails)
            .flatMap { $0 } ?? []
        let thumbnails = (media?.mediaThumbnails ?? []) + grouped

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
