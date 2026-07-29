import Foundation

final class DiskCacheRepository: CacheRepository {
    /// What the cache is allowed to occupy. One entry is a category in a language, so the whole
    /// set is bounded by the categories that exist, but an entry's size is not: it follows the
    /// article limit and the length of the summaries a publisher writes.
    static let defaultSizeLimitInBytes = 8 * 1024 * 1024

    private let directory: URL
    private let sizeLimitInBytes: Int
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL, sizeLimitInBytes: Int = DiskCacheRepository.defaultSizeLimitInBytes) {
        self.directory = directory
        self.sizeLimitInBytes = sizeLimitInBytes
    }

    /// Falls back to the temporary directory rather than subscripting a possibly empty array.
    /// `urls(for:in:)` returning nothing is vanishingly unlikely and the crash it caused would
    /// have been at launch, with no way for a reader to get past it.
    static func defaultDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return caches.appendingPathComponent("articles", isDirectory: true)
    }

    private func fileURL(category: NewsCategory, language: Language) -> URL {
        directory.appendingPathComponent("\(category.rawValue)_\(language.rawValue).json")
    }

    func save(_ entry: CachedArticles, category: NewsCategory, language: Language) throws {
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try encoder.encode(entry)
            try data.write(to: fileURL(category: category, language: language), options: .atomic)
        } catch {
            throw NewsError.cacheFailed
        }
        evictIfOverLimit()
    }

    func load(category: NewsCategory, language: Language) -> CachedArticles? {
        guard let data = try? Data(contentsOf: fileURL(category: category, language: language)),
              let entry = try? decoder.decode(CachedArticles.self, from: data)
        else { return nil }

        // An entry written by a different version of the app is discarded rather than served.
        // Decoding succeeding is not the same as the entry meaning what this version thinks it
        // means, and a plausible wrong answer is worse than a refetch.
        guard entry.matchesCurrentSchema else {
            try? fileManager.removeItem(at: fileURL(category: category, language: language))
            return nil
        }
        return entry
    }

    func totalSizeInBytes() -> Int {
        entries().reduce(0) { $0 + $1.size }
    }

    func clearAll() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            try fileManager.removeItem(at: directory)
        } catch {
            throw NewsError.cacheFailed
        }
    }

    // MARK: - Eviction

    /// Oldest first, which for a cache of categories means the ones the reader has not visited
    /// recently. Predictable in the sense that matters: given the same set of files, the same
    /// ones go, and the newest entry is never the one evicted to make room for itself.
    private func evictIfOverLimit() {
        var all = entries()
        var total = all.reduce(0) { $0 + $1.size }
        guard total > sizeLimitInBytes else { return }

        all.sort { $0.modifiedAt < $1.modifiedAt }
        for entry in all where total > sizeLimitInBytes {
            guard (try? fileManager.removeItem(at: entry.url)) != nil else { continue }
            total -= entry.size
        }
    }

    private struct Entry {
        let url: URL
        let size: Int
        let modifiedAt: Date
    }

    private func entries() -> [Entry] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey]
        ) else { return [] }

        return urls.map { url in
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            return Entry(
                url: url,
                size: values?.fileSize ?? 0,
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }
    }
}
