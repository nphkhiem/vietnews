import Foundation

struct NYTSource: NewsSourceAdapter {
    let source: NewsSource = .nyt
    private let network: NetworkService
    private let apiKey: String

    private static let sections: [NewsCategory: String] = [
        .sport: "sports",
        .hotNews: "home",
        .world: "world",
        .finance: "business",
        .technology: "technology",
        .car: "automobiles"
    ]

    private static let dateFormatter = ISO8601DateFormatter()

    init(network: NetworkService, apiKey: String) {
        self.network = network
        self.apiKey = apiKey
    }

    func supports(category: NewsCategory, language: Language) -> Bool {
        !apiKey.isEmpty && language == .english && Self.sections[category] != nil
    }

    func fetch(category: NewsCategory, language: Language) async throws -> [Article] {
        guard let section = Self.sections[category],
              let url = URL(string: "https://api.nytimes.com/svc/topstories/v2/\(section).json?api-key=\(apiKey)")
        else { return [] }

        let data = try await network.data(from: url)
        let response: NYTTopStoriesDTO
        do {
            response = try JSONDecoder().decode(NYTTopStoriesDTO.self, from: data)
        } catch {
            throw NewsError.parsingFailed(.nyt)
        }

        return response.results.compactMap { dto in
            guard let url = URL(string: dto.url) else { return nil }
            return Article(
                title: dto.title,
                summary: dto.abstract,
                url: url,
                imageURL: dto.multimedia?.first.flatMap { URL(string: $0.url) },
                source: .nyt,
                category: category,
                publishedAt: Self.dateFormatter.date(from: dto.publishedDate) ?? .distantPast
            )
        }
    }
}
