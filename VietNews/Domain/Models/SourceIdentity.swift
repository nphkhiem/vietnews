import Foundation

/// What a health record and an on/off switch attach to.
///
/// `NewsSource` is too coarse to carry either. The Substack adapter serves as many feeds as the
/// reader has added, so a single `.substack` record cannot say which of them is failing, and a
/// single switch cannot turn one of them off. A built-in source is still one identity, because
/// it is one adapter.
enum SourceIdentity: Hashable {
    case builtIn(NewsSource)
    case userFeed(URL)

    /// A stable string, because health is stored as a dictionary and a dictionary written to
    /// `UserDefaults` needs string keys. Prefixed so a feed whose URL happened to read like a
    /// source name could never collide with one.
    var key: String {
        switch self {
        case .builtIn(let source): return "builtIn:\(source.rawValue)"
        case .userFeed(let url): return "userFeed:\(url.absoluteString)"
        }
    }

    init?(key: String) {
        if let raw = key.dropPrefix("builtIn:") {
            guard let source = NewsSource(rawValue: raw) else { return nil }
            self = .builtIn(source)
        } else if let raw = key.dropPrefix("userFeed:") {
            guard let url = URL(string: raw) else { return nil }
            self = .userFeed(url)
        } else {
            return nil
        }
    }
}

private extension String {
    func dropPrefix(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
