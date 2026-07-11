import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var refreshInterval: TimeInterval {
        didSet {
            preferences.refreshInterval = refreshInterval
            scheduler.start(interval: preferences.refreshInterval)
        }
    }

    @Published private(set) var substackFeeds: [SubstackFeed]

    private let preferences: UserPreferences
    private let scheduler: RefreshScheduling

    init(preferences: UserPreferences, scheduler: RefreshScheduling) {
        self.preferences = preferences
        self.scheduler = scheduler
        self.refreshInterval = preferences.refreshInterval
        self.substackFeeds = preferences.substackFeeds
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
