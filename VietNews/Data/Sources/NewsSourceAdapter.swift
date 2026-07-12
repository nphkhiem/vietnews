protocol NewsSourceAdapter {
    var source: NewsSource { get }
    func supports(category: NewsCategory, language: Language) -> Bool
    func fetch(category: NewsCategory, language: Language) async throws -> [Article]
}
