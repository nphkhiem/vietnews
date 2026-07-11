import Foundation

final class DiskCacheRepository: CacheRepository {
    private let directory: URL
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL) {
        self.directory = directory
    }

    static func defaultDirectory() -> URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("articles", isDirectory: true)
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
    }

    func load(category: NewsCategory, language: Language) -> CachedArticles? {
        guard let data = try? Data(contentsOf: fileURL(category: category, language: language)) else {
            return nil
        }
        return try? decoder.decode(CachedArticles.self, from: data)
    }

    func clearAll() throws {
        guard fileManager.fileExists(atPath: directory.path) else { return }
        do {
            try fileManager.removeItem(at: directory)
        } catch {
            throw NewsError.cacheFailed
        }
    }
}
