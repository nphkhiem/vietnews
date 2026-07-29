import Foundation

/// One row on the sources screen: a source, what it is called, and how it is doing.
struct SourceListing: Identifiable, Equatable {
    let identity: SourceIdentity
    let name: String
    /// The categories or languages this source serves, or the category a reader's feed was filed
    /// under. Says what turning it off would cost.
    let scope: String
    let health: SourceHealth
    let isEnabled: Bool

    var id: String { identity.key }
    var isFailing: Bool { health.isFailing }
}

@MainActor
final class SourcesViewModel: ObservableObject {
    @Published private(set) var failing: [SourceListing] = []
    @Published private(set) var builtIn: [SourceListing] = []
    @Published private(set) var userFeeds: [SourceListing] = []

    private let health: SourceHealthRepository
    private let preferences: UserPreferences
    private let language: Language
    /// Which categories a source covers. Supplied by the composition root from the adapters
    /// themselves rather than restated here, so the screen cannot claim a coverage the fetch
    /// does not actually have.
    private let serves: (NewsSource, NewsCategory) -> Bool

    init(
        health: SourceHealthRepository,
        preferences: UserPreferences,
        language: Language,
        serves: @escaping (NewsSource, NewsCategory) -> Bool
    ) {
        self.health = health
        self.preferences = preferences
        self.language = language
        self.serves = serves
        reload()
    }

    /// Failing sources are lifted out of their group rather than merely sorted within it. A
    /// broken source is the reason a reader opened this screen, so it should not be something
    /// they have to find.
    func reload() {
        let all = NewsSource.allCases.map(listing(forBuiltIn:))
            + preferences.substackFeeds.map(listing(forUserFeed:))

        failing = all.filter(\.isFailing)
        let working = all.filter { !$0.isFailing }
        builtIn = working.filter { if case .builtIn = $0.identity { return true } else { return false } }
        userFeeds = working.filter { if case .userFeed = $0.identity { return true } else { return false } }
    }

    func setEnabled(_ isEnabled: Bool, for identity: SourceIdentity) {
        health.setEnabled(isEnabled, for: identity)
        reload()
    }

    private func listing(forBuiltIn source: NewsSource) -> SourceListing {
        let identity = SourceIdentity.builtIn(source)
        return SourceListing(
            identity: identity,
            name: source.displayName,
            scope: scope(of: source),
            health: health.health(for: identity),
            isEnabled: health.isEnabled(identity)
        )
    }

    private func listing(forUserFeed feed: SubstackFeed) -> SourceListing {
        let identity = SourceIdentity.userFeed(feed.url)
        let record = health.health(for: identity)
        return SourceListing(
            identity: identity,
            // Falls back to the host until the feed has been read once and told us its name.
            name: record.publicationTitle ?? feed.url.host ?? feed.url.absoluteString,
            scope: feed.category.displayName(in: language),
            health: record,
            isEnabled: health.isEnabled(identity)
        )
    }

    /// What a source covers, said in the reader's own language: how many categories it serves,
    /// and whether it serves their language at all.
    private func scope(of source: NewsSource) -> String {
        let categories = NewsCategory.allCases.filter { category in
            category.isAvailable(in: language) && serves(source, category)
        }
        guard !categories.isEmpty else {
            return L10n.sourcesNotInLanguage(language)
        }
        return L10nPlural.sourcesCategoryCount(language, count: categories.count)
    }
}
