import Foundation

struct RSSItemDTO: Equatable {
    let title: String
    let link: URL
    let summary: String
    let imageURL: URL?
    let publishedAt: Date?
}
