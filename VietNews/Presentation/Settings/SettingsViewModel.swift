import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    /// One list, shared by the control and by the validation in `UserPreferences`, so the two
    /// cannot drift into offering and accepting different values.
    static let articleCountOptions = [15, 30, 50, 70]

    @Published var refreshInterval: TimeInterval {
        didSet {
            preferences.refreshInterval = refreshInterval
            scheduler.start(interval: preferences.refreshInterval)
        }
    }

    /// Cached entries record the limit they were written under, so raising it invalidates only
    /// what it actually affects and lowering it invalidates nothing. See `CachedArticles`.
    @Published var maxArticles: Int {
        didSet {
            preferences.maxArticles = maxArticles
        }
    }

    @Published private(set) var substackFeeds: [SubstackFeed]

    private let preferences: UserPreferences
    private let scheduler: RefreshScheduling
    private let sourceHealth: SourceHealthRepository
    private let serves: (NewsSource, NewsCategory) -> Bool
    /// Held so the subscription sheet can prove an address is a feed before it is added, using
    /// the same client and parser the fetch itself uses.
    private let network: NetworkService
    private let parser: RSSParsing
    /// Exposed so the storage screen can report and clear what is held, which is the only place
    /// in the app that can see the cache at all.
    let cacheRepository: CacheRepository

    init(
        preferences: UserPreferences,
        scheduler: RefreshScheduling,
        cacheRepository: CacheRepository,
        sourceHealth: SourceHealthRepository,
        serves: @escaping (NewsSource, NewsCategory) -> Bool,
        network: NetworkService,
        parser: RSSParsing
    ) {
        self.preferences = preferences
        self.scheduler = scheduler
        self.cacheRepository = cacheRepository
        self.sourceHealth = sourceHealth
        self.serves = serves
        self.network = network
        self.parser = parser
        self.refreshInterval = preferences.refreshInterval
        self.maxArticles = preferences.maxArticles
        self.substackFeeds = preferences.substackFeeds
    }

    /// Adding a feed is reachable from settings and from the sources screen, and both routes
    /// build the same sheet.
    func makeSubscriptionViewModel() -> FeedSubscriptionViewModel {
        FeedSubscriptionViewModel(
            network: network,
            parser: parser,
            existingFeeds: { [weak self] in self?.substackFeeds ?? [] },
            commit: { [weak self] feed in self?.append(feed) }
        )
    }

    private func append(_ feed: SubstackFeed) {
        substackFeeds.append(feed)
        preferences.substackFeeds = substackFeeds
    }

    /// The sources screen is reachable from here and from a failing-sources banner. Both routes
    /// build it the same way, so neither becomes a second, subtly different screen.
    func makeSourcesViewModel(language: Language) -> SourcesViewModel {
        SourcesViewModel(
            health: sourceHealth,
            preferences: preferences,
            language: language,
            serves: serves
        )
    }

    func addSubstackFeed(urlString: String, category: NewsCategory) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(" ") else { return false }

        var normalized = trimmed
        if !normalized.hasPrefix("http://") && !normalized.hasPrefix("https://") {
            normalized = "https://" + normalized
        }
        if !normalized.hasSuffix("/feed") {
            normalized = normalized.hasSuffix("/") ? normalized + "feed" : normalized + "/feed"
        }

        guard let url = URL(string: normalized),
              let host = url.host,
              host.contains(".")
        else { return false }

        guard !substackFeeds.contains(where: { $0.url == url }) else { return false }

        substackFeeds.append(SubstackFeed(url: url, category: category))
        preferences.substackFeeds = substackFeeds
        return true
    }

    func removeSubstackFeed(at offsets: IndexSet) {
        substackFeeds.remove(atOffsets: offsets)
        preferences.substackFeeds = substackFeeds
    }
}
