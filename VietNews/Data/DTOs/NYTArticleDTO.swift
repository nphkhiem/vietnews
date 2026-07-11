import Foundation

struct NYTTopStoriesDTO: Decodable {
    let results: [NYTArticleDTO]
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
