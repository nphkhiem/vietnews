import Foundation

/// What the app knows about whether each source is working, and which ones the reader has
/// switched off.
///
/// Health is observed and preference is chosen, but they are stored together because they answer
/// the same question at the same moment: should this source have been read, and what happened
/// when it was.
protocol SourceHealthRepository: AnyObject, Sendable {
    func health(for identity: SourceIdentity) -> SourceHealth
    func recordSuccess(_ identity: SourceIdentity, at date: Date, publicationTitle: String?)
    /// Takes no date: the record keeps when a source last *worked*, which is what a reader needs
    /// in order to judge it. When it last broke is always now.
    func recordFailure(_ identity: SourceIdentity, cause: SourceFailureCause)

    /// A source is on unless the reader turned it off, so a source added in a later version is
    /// on by default rather than silently absent.
    func isEnabled(_ identity: SourceIdentity) -> Bool
    func setEnabled(_ isEnabled: Bool, for identity: SourceIdentity)
}
