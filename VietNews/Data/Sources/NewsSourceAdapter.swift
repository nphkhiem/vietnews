import Foundation

protocol NewsSourceAdapter {
    var source: NewsSource { get }
    func supports(category: NewsCategory, language: Language) -> Bool
    /// URLs this adapter would request for the given category and language, empty when it has
    /// nothing to serve. Exposed so a health check can test an endpoint's reachability
    /// separately from whether its response parses.
    func endpoints(category: NewsCategory, language: Language) -> [URL]
    func fetch(category: NewsCategory, language: Language) async throws -> [Article]
}
