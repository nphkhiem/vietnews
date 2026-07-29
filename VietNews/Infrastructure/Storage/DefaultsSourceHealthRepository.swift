import Foundation

/// Source health and switches, kept in `UserDefaults` next to the reader's other preferences.
///
/// Records are written from inside the fetch, which runs several sources concurrently, so the
/// whole map is read, changed and written under a lock. `UserDefaults` is itself thread safe,
/// but that only makes each individual write atomic: without the lock two sources finishing at
/// once would each write back a map that predated the other, and one result would vanish.
final class DefaultsSourceHealthRepository: SourceHealthRepository, @unchecked Sendable {
    private enum Keys {
        static let health = "sources.health"
        static let disabled = "sources.disabled"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func health(for identity: SourceIdentity) -> SourceHealth {
        lock.lock()
        defer { lock.unlock() }
        return storedHealth()[identity.key] ?? .unknown
    }

    func recordSuccess(_ identity: SourceIdentity, at date: Date, publicationTitle: String?) {
        update(identity) { health in
            health.lastSucceededAt = date
            health.lastFailure = nil
            // Only ever learned, never unlearned. A feed that fails to parse once should not
            // lose the name it is listed under.
            if let publicationTitle, !publicationTitle.isEmpty {
                health.publicationTitle = publicationTitle
            }
        }
    }

    func recordFailure(_ identity: SourceIdentity, cause: SourceFailureCause) {
        update(identity) { $0.lastFailure = cause }
    }

    func isEnabled(_ identity: SourceIdentity) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !disabledKeys().contains(identity.key)
    }

    func setEnabled(_ isEnabled: Bool, for identity: SourceIdentity) {
        lock.lock()
        defer { lock.unlock() }
        var keys = disabledKeys()
        if isEnabled {
            keys.remove(identity.key)
        } else {
            keys.insert(identity.key)
        }
        defaults.set(Array(keys), forKey: Keys.disabled)
    }

    // MARK: - Storage

    private func update(_ identity: SourceIdentity, _ change: (inout SourceHealth) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        var map = storedHealth()
        var record = map[identity.key] ?? .unknown
        change(&record)
        map[identity.key] = record
        guard let data = try? JSONEncoder().encode(map) else { return }
        defaults.set(data, forKey: Keys.health)
    }

    private func storedHealth() -> [String: SourceHealth] {
        guard let data = defaults.data(forKey: Keys.health),
              let map = try? JSONDecoder().decode([String: SourceHealth].self, from: data)
        else { return [:] }
        return map
    }

    private func disabledKeys() -> Set<String> {
        Set(defaults.stringArray(forKey: Keys.disabled) ?? [])
    }
}
