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
    /// Whether the articles on screen are old enough to be worth mentioning. Driven by the age
    /// of the data, not by whether this particular response happened to come from the cache: a
    /// cache hit moments after a successful fetch is not a staleness event.
    @Published private(set) var isShowingStaleData = false
    /// A failure that happened while articles were already on screen. Previously such a failure
    /// produced no feedback at all: the reader pulled to refresh and nothing happened.
    @Published private(set) var refreshFailureMessage: String?

    private let fetchNews: FetchNewsUseCase
    private let refreshNews: RefreshNewsUseCase
    private let preferences: UserPreferences
    private let scheduler: RefreshScheduling
    private let now: () -> Date
    private let isOnline: () -> Bool
    private var isSchedulerArmed = false
    private var loadTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(
        fetchNews: FetchNewsUseCase,
        refreshNews: RefreshNewsUseCase,
        preferences: UserPreferences,
        scheduler: RefreshScheduling,
        now: @escaping () -> Date = Date.init,
        isOnline: @escaping () -> Bool = { true }
    ) {
        self.fetchNews = fetchNews
        self.refreshNews = refreshNews
        self.preferences = preferences
        self.scheduler = scheduler
        self.now = now
        self.isOnline = isOnline
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
        refreshFailureMessage = nil
        lastUpdated = result.lastUpdated
        isShowingStaleData = isStale(asOf: result.lastUpdated)
        state = result.articles.isEmpty ? .empty : .loaded
    }

    /// Older than the reader's own refresh cadence is the threshold, so the notice means "your
    /// feed missed at least one refresh" rather than an arbitrary duration.
    private func isStale(asOf lastUpdated: Date) -> Bool {
        now().timeIntervalSince(lastUpdated) >= preferences.refreshInterval
    }

    private func applyFailure(_ error: Error, for category: NewsCategory, language: Language) {
        guard !isStale(category, language) else { return }
        let message = errorMessage(for: error)
        if articles.isEmpty {
            state = .failed(message)
        } else {
            refreshFailureMessage = message
        }
    }

    /// Connectivity is checked before blaming the network, because "you are offline" is only
    /// useful when it is true. A device that is online and sources that are all refusing are two
    /// different problems with two different next steps.
    private func errorMessage(for error: Error) -> String {
        let isVietnamese = language == .vietnamese

        guard isOnline() else {
            return isVietnamese
                ? "Không có kết nối mạng. Kiểm tra Wi-Fi hoặc dữ liệu di động."
                : "No internet connection. Check Wi-Fi or mobile data."
        }

        switch cause(of: error) {
        case .timedOut:
            return isVietnamese
                ? "Các nguồn tin phản hồi quá chậm. Thử lại sau ít phút."
                : "The sources are responding too slowly. Try again in a moment."
        case .rejected:
            return isVietnamese
                ? "Nguồn tin từ chối yêu cầu. Có thể khả dụng lại sau."
                : "The sources refused the request. They may be available again later."
        case .unparseable:
            return isVietnamese
                ? "Không đọc được dữ liệu từ nguồn tin."
                : "The news from these sources could not be read."
        case .unreachable:
            return isVietnamese
                ? "Không liên lạc được với nguồn tin."
                : "The sources could not be reached."
        case .mixed, .none:
            return isVietnamese
                ? "Không thể tải tin tức. Vui lòng thử lại."
                : "Could not load news. Please try again."
        }
    }

    private func cause(of error: Error) -> SourceFailureCause? {
        switch error as? NewsError {
        case .allSourcesFailed(_, let cause): return cause
        case .sourceTimeout: return .timedOut
        case .invalidResponse: return .rejected
        case .parsingFailed: return .unparseable
        case .networkUnavailable: return .unreachable
        case .cacheFailed, .none: return nil
        }
    }
}
