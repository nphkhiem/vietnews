import Foundation

/// Display names for domain values.
///
/// These used to live on the models themselves, which meant the domain layer carried user-facing
/// copy and had to know about languages. Category availability stayed behind in the domain,
/// because which categories exist in a language is behaviour rather than wording.
extension NewsCategory {
    func displayName(in language: Language) -> String {
        Self.localizationKeys[self].map { $0(language) } ?? rawValue
    }

    private static let localizationKeys: [NewsCategory: L10n] = [
        .hotNews: .categoryHotNews,
        .sport: .categorySport,
        .world: .categoryWorld,
        .finance: .categoryFinance,
        .work: .categoryWork,
        .technology: .categoryTechnology,
        .car: .categoryCar,
        .social: .categorySocial,
        .game: .categoryGame
    ]
}

extension NewsSource {
    /// Publication names are proper nouns, so they read the same in every language and are not
    /// part of the string tables. They are still presentation, which is why they live here.
    var displayName: String {
        switch self {
        case .vnexpress: return "VNExpress"
        case .substack: return "Substack"
        case .nyt: return "NY Times"
        case .bbc: return "BBC News"
        case .eurogamer: return "Eurogamer"
        }
    }
}
