import Foundation

/// What the last attempt to read a source told us about it.
///
/// A source that has never been attempted has no record at all, which is why every field is
/// optional and why "never" is a state the interface has to be able to say out loud. Before
/// this, a source that had been broken for weeks was indistinguishable from one nobody had
/// asked for yet: both simply contributed nothing to the feed.
struct SourceHealth: Equatable, Codable {
    var lastSucceededAt: Date?
    /// Why the most recent attempt failed, or nil when it worked. Not a running tally: what the
    /// reader needs to decide is whether the source works now.
    var lastFailure: SourceFailureCause?
    /// The publication's own name, learned from the feed the first time it is read. A reader's
    /// own feed is listed by this rather than by hostname.
    var publicationTitle: String?

    var isFailing: Bool { lastFailure != nil }

    static let unknown = SourceHealth()
}
