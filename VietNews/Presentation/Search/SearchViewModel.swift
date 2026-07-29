import Foundation

/// Search across what is already on the device.
///
/// Reads the cache and nothing else, so it works with no connection and costs no requests. A
/// reader looking for something they remember reading has, by definition, already downloaded it.
@MainActor
final class SearchViewModel: ObservableObject {
    @Published var query: String = "" {
        didSet {
            guard query != oldValue else { return }
            results = Self.matches(for: query, in: corpus)
        }
    }

    @Published private(set) var results: [Article] = []
    private(set) var corpus: [Article] = []

    private let cache: CacheRepository
    private let language: Language

    init(cache: CacheRepository, language: Language) {
        self.cache = cache
        self.language = language
    }

    /// Loaded once when the screen opens rather than per keystroke, because every category in the
    /// reader's language is a separate file and re-reading them all on each character typed would
    /// make typing the slow part.
    func load() {
        var seen = Set<String>()
        corpus = NewsCategory.allCases
            .filter { $0.isAvailable(in: language) }
            .compactMap { cache.load(category: $0, language: language) }
            .flatMap(\.articles)
            // The same article appears in more than one category, and a reader searching does not
            // want to be shown it twice.
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.publishedAt ?? .distantPast) > ($1.publishedAt ?? .distantPast) }

        results = Self.matches(for: query, in: corpus)
    }

    /// A blank query shows nothing rather than everything: a list of every cached article is not
    /// a search result, and the reader already has the feed for that.
    static func matches(for query: String, in corpus: [Article]) -> [Article] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return corpus.filter {
            $0.title.matchesSearch(trimmed) || $0.summary.matchesSearch(trimmed)
        }
    }
}

extension String {
    /// Case and diacritic insensitive, which is not a nicety in Vietnamese: a reader typing
    /// "the thao" expects to find "Thể thao", and typing the tone marks correctly on a phone
    /// keyboard is exactly the work search is meant to save them.
    var searchOptions: String.CompareOptions { [.caseInsensitive, .diacriticInsensitive] }

    func matchesSearch(_ term: String) -> Bool {
        range(of: term, options: searchOptions) != nil
    }

    /// Every range of the original string that matches, so a caller can mark them without having
    /// to map indices back from a folded copy. Foundation reports ranges in this string, which is
    /// what makes that unnecessary.
    func searchRanges(of term: String) -> [Range<String.Index>] {
        guard !term.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchStart = startIndex

        while searchStart < endIndex,
              let found = range(of: term, options: searchOptions, range: searchStart..<endIndex) {
            ranges.append(found)
            // A zero width match would spin here forever, so always move at least one character.
            searchStart = found.isEmpty ? index(after: found.lowerBound) : found.upperBound
        }
        return ranges
    }
}
