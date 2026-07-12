import Foundation

struct RedditSource: NewsSourceAdapter {
    let source: NewsSource = .reddit
    private let network: NetworkService

    private static let subreddits: [NewsCategory: String] = [
        .sport: "sports",
        .hotNews: "news",
        .world: "worldnews",
        .finance: "finance",
        .work: "careerguidance",
        .technology: "technology",
        .car: "cars",
        .game: "gaming"
        // .social intentionally omitted: Social is Vietnamese-only (see
        // NewsCategory.isAvailable), and RedditSource is English-only overall
        // (see supports(category:language:) below), so this entry could
        // never be reached - removed rather than left as dead configuration.
    ]

    init(network: NetworkService) {
        self.network = network
    }

    func supports(category: NewsCategory, language: Language) -> Bool {
        language == .english && Self.subreddits[category] != nil
    }

    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        guard let subreddit = Self.subreddits[category],
              let url = URL(string: "https://www.reddit.com/r/\(subreddit)/hot.json?limit=15")
        else { return [] }

        let data = try await network.data(from: url)
        let listing: RedditListingDTO
        do {
            listing = try JSONDecoder().decode(RedditListingDTO.self, from: data)
        } catch {
            throw NewsError.parsingFailed(.reddit)
        }

        return listing.data.children.compactMap { child in
            let post = child.data
            guard let url = URL(string: "https://www.reddit.com\(post.permalink)") else { return nil }
            let thumbnail = post.thumbnail.flatMap { $0.hasPrefix("http") ? URL(string: $0) : nil }
            return Article(
                title: post.title,
                summary: post.selftext ?? "",
                url: url,
                imageURL: thumbnail,
                source: .reddit,
                category: category,
                publishedAt: Date(timeIntervalSince1970: post.createdUTC)
            )
        }
    }
}
