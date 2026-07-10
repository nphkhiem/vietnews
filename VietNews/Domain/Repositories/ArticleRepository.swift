struct FetchResult: Equatable {
    let articles: [Article]
    let failedSources: [NewsSource]
}

protocol ArticleRepository {
    func fetchArticles(category: NewsCategory, language: Language) async throws -> FetchResult
}
