import Foundation

final class UserPreferences {
    private enum Keys {
        static let language = "preferences.language"
        static let refreshInterval = "preferences.refreshInterval"
        static let substackFeeds = "preferences.substackFeeds"
        static let maxArticles = "preferences.maxArticles"
    }

    /// Zero means off. The rest are the intervals a reader might plausibly want, rather than a
    /// slider over a five to ten minute band that offered no real choice and could not be
    /// switched off at all.
    static let refreshIntervalOptions: [TimeInterval] = [0, 300, 900, 1_800, 3_600]
    private static let validMaxArticlesOptions: [Int] = [15, 30, 50, 70]

    private static let defaultSubstackFeeds: [SubstackFeed] = [
        SubstackFeed(url: URL(string: "https://www.lennysnewsletter.com/feed")!, category: .work),
        SubstackFeed(url: URL(string: "https://newsletter.pragmaticengineer.com/feed")!, category: .technology)
    ]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var language: Language {
        get {
            defaults.string(forKey: Keys.language).flatMap(Language.init(rawValue:)) ?? .vietnamese
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.language)
        }
    }

    /// Zero is a real choice now, so an unset preference cannot be represented by zero the way
    /// it was. The absence of the key is what means "never set", and that defaults to five
    /// minutes; a stored zero means the reader turned it off.
    var refreshInterval: TimeInterval {
        get {
            guard defaults.object(forKey: Keys.refreshInterval) != nil else { return 300 }
            let stored = defaults.double(forKey: Keys.refreshInterval)
            return Self.refreshIntervalOptions.contains(stored) ? stored : 300
        }
        set {
            let snapped = Self.refreshIntervalOptions.contains(newValue) ? newValue : 300
            defaults.set(snapped, forKey: Keys.refreshInterval)
        }
    }

    /// How long cached articles stay current. Follows the chosen interval, so a reader who asked
    /// for hourly refreshes is not served a refetch every five minutes by a separate fixed
    /// number they never saw. With automatic refresh off, the cache still ages out, otherwise
    /// pulling to refresh would be the only way the app ever saw new articles.
    var cacheTTL: TimeInterval {
        let interval = refreshInterval
        return interval > 0 ? interval : 900
    }

    var substackFeeds: [SubstackFeed] {
        get {
            guard let data = defaults.data(forKey: Keys.substackFeeds),
                  let feeds = try? JSONDecoder().decode([SubstackFeed].self, from: data)
            else { return Self.defaultSubstackFeeds }
            return feeds
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue) else { return }
            defaults.set(data, forKey: Keys.substackFeeds)
        }
    }

    var maxArticles: Int {
        get {
            let stored = defaults.integer(forKey: Keys.maxArticles)
            return Self.validMaxArticlesOptions.contains(stored) ? stored : 15
        }
        set {
            let snapped = Self.validMaxArticlesOptions.contains(newValue) ? newValue : 15
            defaults.set(snapped, forKey: Keys.maxArticles)
        }
    }
}
