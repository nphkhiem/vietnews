import Foundation

struct RedditListingDTO: Decodable {
    let data: Listing

    struct Listing: Decodable {
        let children: [Child]
    }

    struct Child: Decodable {
        let data: RedditPostDTO
    }
}

struct RedditPostDTO: Decodable {
    let title: String
    let permalink: String
    let createdUTC: TimeInterval
    let thumbnail: String?
    let selftext: String?

    enum CodingKeys: String, CodingKey {
        case title, permalink, thumbnail, selftext
        case createdUTC = "created_utc"
    }
}
