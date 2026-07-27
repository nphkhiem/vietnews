import Foundation

protocol NetworkService {
    func data(from url: URL) async throws -> Data
}

final class URLSessionNetworkService: NetworkService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func data(from url: URL) async throws -> Data {
        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw NewsError.invalidResponse(statusCode: -1)
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
