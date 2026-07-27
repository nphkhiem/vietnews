import Foundation

struct NYTTopStoriesDTO: Decodable {
    let results: [NYTArticleDTO]

    /// A section with no stories answers with `results: null` rather than an empty array, and
    /// treating that as a parse failure reports a working endpoint as broken.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = try container.decodeIfPresent([NYTArticleDTO].self, forKey: .results) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case results
    }
}

struct NYTArticleDTO: Decodable {
    let title: String
    let abstract: String
    let url: String
    let publishedDate: String
    let multimedia: [Multimedia]?

    enum CodingKeys: String, CodingKey {
        case title, abstract, url, multimedia
        case publishedDate = "published_date"
    }

    struct Multimedia: Decodable {
        let url: String
    }
}
