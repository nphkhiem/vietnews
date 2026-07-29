import Foundation

protocol NetworkService {
    func data(from url: URL) async throws -> Data
}

final class URLSessionNetworkService: NetworkService {
    /// Matches the per source budget in `RemoteArticleRepository`. Without it a request inherits
    /// the system default of sixty seconds, so the repository's own timeout was the only thing
    /// ever stopping a hung source, and it stopped it by abandoning a request that carried on.
    static let defaultTimeout: TimeInterval = 10

    private let session: URLSession
    private let timeout: TimeInterval
    private let userAgent: String

    init(
        session: URLSession = .shared,
        timeout: TimeInterval = URLSessionNetworkService.defaultTimeout,
        userAgent: String = URLSessionNetworkService.defaultUserAgent()
    ) {
        self.session = session
        self.timeout = timeout
        self.userAgent = userAgent
    }

    /// Says who is asking. Publishers block or throttle clients they cannot identify, and an
    /// unnamed reader has no way to be contacted before being cut off.
    static func defaultUserAgent(bundle: Bundle = .main) -> String {
        let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "VietNews"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "\(name)/\(version) (+https://github.com/nphkhiem/vietnews)"
    }

    func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            // Named, rather than a status code of -1 standing in for "there was no status code".
            // A reader was previously told the server answered with -1, which is not a thing.
            throw NewsError.nonHTTPResponse
        }
        if http.statusCode == 429 {
            throw NewsError.rateLimited(retryAfter: Self.retryAfter(from: http))
        }
        guard (200...299).contains(http.statusCode) else {
            throw NewsError.invalidResponse(statusCode: http.statusCode)
        }
        return data
    }

    /// `Retry-After` is either a number of seconds or an HTTP date. Both are read, because a
    /// server that tells us when to come back should be believed rather than guessed at.
    static func retryAfter(from response: HTTPURLResponse) -> TimeInterval? {
        guard let value = response.value(forHTTPHeaderField: "Retry-After")?
            .trimmingCharacters(in: .whitespaces), !value.isEmpty
        else { return nil }

        if let seconds = TimeInterval(value) {
            return max(0, seconds)
        }
        guard let date = httpDateFormatter.date(from: value) else { return nil }
        return max(0, date.timeIntervalSinceNow)
    }

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}
