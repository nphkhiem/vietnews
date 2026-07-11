import Foundation

struct Article: Identifiable, Equatable, Codable {
    let id: String
    let title: String
    let summary: String
    let url: URL
    let imageURL: URL?
    let source: NewsSource
    let category: NewsCategory
    let publishedAt: Date

    init(
        title: String,
        summary: String,
        url: URL,
        imageURL: URL?,
        source: NewsSource,
        category: NewsCategory,
        publishedAt: Date
    ) {
        self.id = url.absoluteString
        self.title = title
        self.summary = summary
        self.url = url
        self.imageURL = imageURL
        self.source = source
        self.category = category
        self.publishedAt = publishedAt
    }
}
