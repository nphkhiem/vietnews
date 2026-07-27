import Foundation

/// Keeps a minimum gap between requests to the same host.
///
/// A category load fans out across every source at once and prefetches neighbouring categories,
/// which means several requests can hit one host within milliseconds. Providers that count
/// requests per minute treat that as a burst, which is how a working section ends up answering
/// 429 while its neighbours succeed.
actor HostRequestPacer {
    private let minimumInterval: TimeInterval
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void
    private var nextAllowed: [String: Date] = [:]

    init(
        minimumInterval: TimeInterval = 0.4,
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.minimumInterval = minimumInterval
        self.now = now
        self.sleep = sleep
    }

    func waitForTurn(host: String) async {
        let current = now()
        let allowedAt = nextAllowed[host] ?? current
        // Reserve this host's slot before suspending, so concurrent callers queue rather than all
        // measuring against the same past instant and proceeding together.
        nextAllowed[host] = max(allowedAt, current).addingTimeInterval(minimumInterval)

        let delay = allowedAt.timeIntervalSince(current)
        guard delay > 0 else { return }
        try? await sleep(delay)
    }
}

/// Retries requests that failed for a reason likely to pass on its own, and paces requests per
/// host so a burst does not create those failures in the first place.
final class RetryingNetworkService: NetworkService {
    private let wrapped: NetworkService
    private let maxAttempts: Int
    private let baseDelay: TimeInterval
    private let pacer: HostRequestPacer
    private let sleep: (TimeInterval) async throws -> Void

    init(
        wrapping wrapped: NetworkService,
        maxAttempts: Int = 3,
        baseDelay: TimeInterval = 0.5,
        pacer: HostRequestPacer = HostRequestPacer(),
        sleep: @escaping (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        }
    ) {
        self.wrapped = wrapped
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.pacer = pacer
        self.sleep = sleep
    }

    func data(from url: URL) async throws -> Data {
        var attempt = 1
        while true {
            if let host = url.host {
                await pacer.waitForTurn(host: host)
            }

            do {
                return try await wrapped.data(from: url)
            } catch {
                guard attempt < maxAttempts, let delay = retryDelay(for: error, attempt: attempt) else {
                    throw error
                }
                try await sleep(delay)
                attempt += 1
            }
        }
    }

    /// Returns how long to wait before trying again, or nil when retrying cannot help. A refusal
    /// or an unreadable response will fail the same way a moment later; a rate limit or a server
    /// error will not.
    private func retryDelay(for error: Error, attempt: Int) -> TimeInterval? {
        let backoff = baseDelay * pow(2, Double(attempt - 1))

        switch error {
        case NewsError.rateLimited(let retryAfter):
            // The server's own figure wins over our guess, in both directions.
            return retryAfter ?? backoff
        case NewsError.invalidResponse(let statusCode) where (500...599).contains(statusCode):
            return backoff
        case let urlError as URLError where Self.isTransient(urlError):
            return backoff
        default:
            return nil
        }
    }

    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed:
            return true
        default:
            return false
        }
    }
}
