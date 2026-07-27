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
    private let preferences: UserPreferences
    private let scheduler: RefreshScheduling
    private var isSchedulerArmed = false
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(
        fetchNews: FetchNewsUseCase,
        refreshNews: RefreshNewsUseCase,
        preferences: UserPreferences,
        scheduler: RefreshScheduling
    ) {
        self.fetchNews = fetchNews
        self.refreshNews = refreshNews
        self.preferences = preferences
        self.scheduler = scheduler
        self.language = preferences.language
    }

    /// Arms the auto-refresh timer and performs the initial load. The view calls this both when
    /// the feed appears and when the scene becomes active, which happens within moments of each
    /// other at launch, so both the arming and the load are deliberately idempotent.
    func start() async {
        armSchedulerIfNeeded()
        await load()
    }

    func stop() {
        scheduler.stop()
        isSchedulerArmed = false
    }

    /// Coalesces concurrent loads. A timer tick, a foreground transition, and the initial appear
    /// can all arrive at once, and each one starting its own fan-out across every source would
    /// multiply network traffic and let a later response overwrite an earlier one.
    func load() async {
        if let inFlight = loadTask {
            await inFlight.value
            return
        }

        loadGeneration += 1
        let generation = loadGeneration
        let task = Task { await self.performLoad() }
        loadTask = task
        await task.value
        if generation == loadGeneration {
            loadTask = nil
        }
    }

    private func performLoad() async {
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

    /// Used when the selection changes: an in-flight load is for the previous category or
    /// language, so joining it would be wrong. Discard it and start over.
    private func reload() async {
        loadTask?.cancel()
        loadTask = nil
        await load()
    }

    private func armSchedulerIfNeeded() {
        guard !isSchedulerArmed else { return }
        isSchedulerArmed = true
        scheduler.onTick = { [weak self] in
            guard let self else { return }
            Task(priority: .background) {
                await self.load()
                await self.prefetchAdjacentCategories()
            }
        }
        scheduler.start(interval: preferences.refreshInterval)
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
        await reload()
    }

    func setLanguage(_ newLanguage: Language) async {
        guard newLanguage != language else { return }
        language = newLanguage
        preferences.language = newLanguage
        if !selectedCategory.isAvailable(in: newLanguage) {
            selectedCategory = .hotNews
        }
        articles = []
        await reload()
    }

    func prefetchAdjacentCategories() async {
        let all = NewsCategory.allCases
        guard let index = all.firstIndex(of: selectedCategory) else { return }
        let neighbors = [index - 1, index + 1]
            .filter(all.indices.contains)
            .map { all[$0] }
            .filter { $0.isAvailable(in: language) }
        for category in neighbors {
            _ = try? await fetchNews.execute(category: category, language: language)
        }
    }

    /// Ignores responses that no longer match the currently selected category/language
    /// (a stale in-flight request, e.g. from a prior category or a background refresh
    /// tick, must not clobber state for whatever the user has since switched to).
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
