import Foundation

/// The articles the reader has already opened, kept across launches.
///
/// Held in memory and written through, because the feed asks whether an article is read once per
/// row per redraw and that cannot go to `UserDefaults` each time.
///
/// The list is bounded. Read state that only ever grew would be a store the app can never
/// reclaim, so the oldest entries are dropped once the cap is reached. The cap sits above the
/// largest feed the app can produce, which is the article limit times the number of categories,
/// so an article still on screen can never be forgotten while the reader is looking at it.
final class ReadArticleStore {
    static let defaultLimit = 1_000

    private enum Keys {
        static let readArticles = "reader.readArticleIDs"
    }

    private let defaults: UserDefaults
    private let limit: Int
    /// Oldest first, so eviction is a prefix drop.
    private var ordered: [String]
    private var lookup: Set<String>

    init(defaults: UserDefaults = .standard, limit: Int = ReadArticleStore.defaultLimit) {
        self.defaults = defaults
        self.limit = max(1, limit)
        let stored = defaults.stringArray(forKey: Keys.readArticles) ?? []
        self.ordered = stored.suffix(self.limit)
        self.lookup = Set(self.ordered)
    }

    var readIDs: Set<String> { lookup }

    /// Re-reading an article moves it to the newest end rather than doing nothing, so something
    /// the reader keeps coming back to is not the first thing evicted.
    func markRead(_ id: String) {
        if lookup.contains(id) {
            ordered.removeAll { $0 == id }
        }
        ordered.append(id)
        lookup.insert(id)

        if ordered.count > limit {
            let evicted = ordered.prefix(ordered.count - limit)
            ordered.removeFirst(ordered.count - limit)
            lookup.subtract(evicted)
        }

        defaults.set(ordered, forKey: Keys.readArticles)
    }
}
