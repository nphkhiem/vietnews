import Foundation

/// Articles the reader chose to keep, newest saved first.
///
/// The whole article is stored, not just its identifier, which is what makes the saved list
/// readable with no connection: a saved article is no longer something the app has to go and
/// fetch again before it can show it.
///
/// Deliberately unbounded, unlike `ReadArticleStore`. Read state accumulates on its own and has
/// to be reclaimed, but saving is a thing the reader did on purpose, and silently discarding
/// their oldest save to make room would be worse than the space it costs.
@MainActor
final class SavedArticleStore: ObservableObject {
    private enum Keys {
        static let saved = "reader.savedArticles"
    }

    @Published private(set) var articles: [Article]
    private var savedIDs: Set<String>
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let stored = defaults.data(forKey: Keys.saved)
            .flatMap { try? JSONDecoder().decode([Article].self, from: $0) }
            ?? []
        self.articles = stored
        self.savedIDs = Set(stored.map(\.id))
    }

    func isSaved(_ id: String) -> Bool { savedIDs.contains(id) }

    /// Saving and unsaving are the same gesture, because the row shows which one it is about to
    /// do. Returns the state it settled on so a caller can announce it.
    @discardableResult
    func toggle(_ article: Article) -> Bool {
        if savedIDs.contains(article.id) {
            remove(id: article.id)
            return false
        }
        articles.insert(article, at: 0)
        savedIDs.insert(article.id)
        persist()
        return true
    }

    func remove(id: String) {
        guard savedIDs.contains(id) else { return }
        articles.removeAll { $0.id == id }
        savedIDs.remove(id)
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(articles) else { return }
        defaults.set(data, forKey: Keys.saved)
    }
}
