import Foundation

/// Adding a feed, as a task with a beginning and an end.
///
/// It used to be three controls loose in a form with the confirm button below the fold, and the
/// only feedback was an alert saying the address was invalid. Nothing told the reader whether the
/// address was a feed at all until articles either appeared or did not.
@MainActor
final class FeedSubscriptionViewModel: ObservableObject {
    enum AddressState: Equatable {
        case empty
        /// Says what is wrong while the reader is still typing, rather than on submit.
        case invalid(Problem)
        case usable(URL)
    }

    enum Problem: Equatable {
        case notAnAddress
        /// Blocked before it is attempted. App Transport Security would refuse it anyway, and
        /// "could not be reached" would be a misleading way to report a rule of our own.
        case insecure
        case alreadyFollowed
        case unreachable
        case unreadable
    }

    struct Preview: Equatable {
        /// What the feed calls itself, which is what the sources screen will list it as.
        let title: String
        let itemTitles: [String]
        /// The address that actually answered, which is not always the one typed.
        let resolved: URL
    }

    enum PreviewState: Equatable {
        case idle
        case checking
        case found(Preview)
        case failed(Problem)
    }

    @Published var address: String = "" {
        didSet {
            guard address != oldValue else { return }
            // Any edit invalidates what was proven about the previous address.
            previewState = .idle
            addressState = Self.validate(address, against: existingFeeds())
        }
    }

    @Published var category: NewsCategory = .technology
    @Published private(set) var addressState: AddressState = .empty
    @Published private(set) var previewState: PreviewState = .idle

    private let network: NetworkService
    private let parser: RSSParsing
    private let existingFeeds: () -> [SubstackFeed]
    private let commit: (SubstackFeed) -> Void

    init(
        network: NetworkService,
        parser: RSSParsing,
        existingFeeds: @escaping () -> [SubstackFeed],
        commit: @escaping (SubstackFeed) -> Void
    ) {
        self.network = network
        self.parser = parser
        self.existingFeeds = existingFeeds
        self.commit = commit
    }

    /// Whether the reader may commit. Deliberately requires a successful preview: the point of
    /// the sheet is that they see proof it works before they add it.
    var canAdd: Bool {
        if case .found = previewState { return true }
        return false
    }

    func check() async {
        guard case .usable(let url) = addressState else { return }
        previewState = .checking

        // Tried as typed first, then with `/feed` appended. Many publications sit at a bare
        // domain and the feed one level down, and the reader should not have to know which.
        var anythingAnswered = false

        for candidate in Self.candidates(for: url) {
            guard let data = try? await network.data(from: candidate) else { continue }
            anythingAnswered = true
            guard let items = try? parser.parse(data) else { continue }

            previewState = .found(
                Preview(
                    title: parser.channelTitle(in: data) ?? candidate.host ?? candidate.absoluteString,
                    itemTitles: Array(items.prefix(3).map(\.title)),
                    resolved: candidate
                )
            )
            return
        }

        // An address that could not be reached and one that answered with something unreadable
        // are different problems, told apart by whether anything answered at all.
        previewState = .failed(anythingAnswered ? .unreadable : .unreachable)
    }

    /// Reports whether the feed was added. Checked again here because the address that answered
    /// is not always the one typed, so a duplicate can only be certain once it is resolved.
    @discardableResult
    func add() -> Bool {
        guard case .found(let preview) = previewState else { return false }
        guard !existingFeeds().contains(where: { $0.url == preview.resolved }) else {
            previewState = .failed(.alreadyFollowed)
            return false
        }
        commit(SubstackFeed(url: preview.resolved, category: category))
        return true
    }

    // MARK: - Validation

    static func validate(_ input: String, against existing: [SubstackFeed]) -> AddressState {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        if trimmed.lowercased().hasPrefix("http://") { return .invalid(.insecure) }
        guard !trimmed.contains(" ") else { return .invalid(.notAnAddress) }

        let normalized = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: normalized),
              let host = url.host,
              host.contains("."),
              !host.hasPrefix("."),
              !host.hasSuffix(".")
        else { return .invalid(.notAnAddress) }

        // Checked here as well as on commit, so the reader is told before they go looking for a
        // preview of something they already follow.
        if existing.contains(where: { $0.url.host == host }) { return .invalid(.alreadyFollowed) }

        return .usable(url)
    }

    private static func candidates(for url: URL) -> [URL] {
        guard !url.path.hasSuffix("/feed"), url.path != "/feed" else { return [url] }
        let withFeed = url.appendingPathComponent("feed")
        return [url, withFeed]
    }
}
