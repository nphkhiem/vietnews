import Foundation

@MainActor
final class NewsFeedViewModel: ObservableObject {
    enum ViewState: Equatable {
        case loading
        case loaded
        case empty
        case failed(String)
    }

    @Published private(set) var state: ViewState = .loading
    @Published private(set) var articles: [Article] = []
    @Published private(set) var selectedCategory: NewsCategory = .hotNews
    @Published private(set) var language: Language
    @Published private(set) var failedSources: [NewsSource] = []
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isShowingCachedData = false

    private let fetchNews: FetchNewsUseCase
    private let refreshNews: RefreshNewsUseCase
    private let cacheRepository: CacheRepository
    private let preferences: UserPreferences
    private let scheduler: RefreshScheduling

    init(
        fetchNews: FetchNewsUseCase,
        refreshNews: RefreshNewsUseCase,
        cacheRepository: CacheRepository,
        preferences: UserPreferences,
        scheduler: RefreshScheduling
    ) {
        self.fetchNews = fetchNews
        self.refreshNews = refreshNews
        self.cacheRepository = cacheRepository
        self.preferences = preferences
        self.scheduler = scheduler
        self.language = preferences.language
    }

    func start() async {
        scheduler.onTick = { [weak self] in
            guard let self else { return }
            Task(priority: .background) {
                await self.load()
                await self.prefetchAdjacentCategories()
            }
        }
        scheduler.start(interval: preferences.refreshInterval)
        await load()
    }

    func stop() {
        scheduler.stop()
    }

    func load() async {
        if articles.isEmpty {
            state = .loading
        }
        let requestedCategory = selectedCategory
        let requestedLanguage = language
        do {
            let result = try await fetchNews.execute(category: requestedCategory, language: requestedLanguage)
            apply(result, for: requestedCategory, language: requestedLanguage)
        } catch {
            applyFailure(error, for: requestedCategory, language: requestedLanguage)
        }
    }

    func refresh() async {
        let requestedCategory = selectedCategory
        let requestedLanguage = language
        do {
            let result = try await refreshNews.execute(category: requestedCategory, language: requestedLanguage)
            apply(result, for: requestedCategory, language: requestedLanguage)
        } catch {
            applyFailure(error, for: requestedCategory, language: requestedLanguage)
        }
    }

    func selectCategory(_ category: NewsCategory) async {
        guard category != selectedCategory else { return }
        selectedCategory = category
        articles = []
        await load()
    }

    func setLanguage(_ newLanguage: Language) async {
        guard newLanguage != language else { return }
        language = newLanguage
        preferences.language = newLanguage
        try? cacheRepository.clearAll()
        articles = []
        await load()
    }

    func prefetchAdjacentCategories() async {
        let all = NewsCategory.allCases
        guard let index = all.firstIndex(of: selectedCategory) else { return }
        let neighbors = [index - 1, index + 1]
            .filter(all.indices.contains)
            .map { all[$0] }
        for category in neighbors {
            _ = try? await fetchNews.execute(category: category, language: language)
        }
    }

    /// Ignores responses that no longer match the currently selected category/language —
    /// a stale in-flight request (e.g. from a prior category or a background refresh tick)
    /// must not clobber state for whatever the user has since switched to.
    private func isStale(_ category: NewsCategory, _ language: Language) -> Bool {
        category != selectedCategory || language != self.language
    }

    private func apply(_ result: NewsFeedResult, for category: NewsCategory, language: Language) {
        guard !isStale(category, language) else { return }
        articles = result.articles
        failedSources = result.failedSources
        lastUpdated = result.lastUpdated
        isShowingCachedData = result.isFromCache
        state = result.articles.isEmpty ? .empty : .loaded
    }

    private func applyFailure(_ error: Error, for category: NewsCategory, language: Language) {
        guard !isStale(category, language) else { return }
        if articles.isEmpty {
            state = .failed(errorMessage(for: error))
        }
    }

    private func errorMessage(for error: Error) -> String {
        switch language {
        case .vietnamese: return "Không thể tải tin tức. Vui lòng thử lại."
        case .english: return "Could not load news. Please try again."
        }
    }
}
