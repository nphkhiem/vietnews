import Foundation

final class UserPreferences {
    private enum Keys {
        static let language = "preferences.language"
        static let refreshInterval = "preferences.refreshInterval"
        static let substackFeeds = "preferences.substackFeeds"
        static let maxArticles = "preferences.maxArticles"
    }

    private static let intervalRange: ClosedRange<TimeInterval> = 300...600
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

    var refreshInterval: TimeInterval {
        get {
            let stored = defaults.double(forKey: Keys.refreshInterval)
            return stored == 0 ? 300 : stored
        }
        set {
            let clamped = min(max(newValue, Self.intervalRange.lowerBound), Self.intervalRange.upperBound)
            defaults.set(clamped, forKey: Keys.refreshInterval)
        }
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
