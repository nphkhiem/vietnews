import Foundation

/// Why every source applicable to a request failed, in terms the interface can turn into copy
/// that suggests what the reader might do next.
enum SourceFailureCause: String, Equatable, Hashable, Codable {
    /// Sources did not answer within their budget.
    case timedOut
    /// Sources answered, but refused the request.
    case rejected
    /// Sources are rate limiting us. Unlike a refusal, this is expected to pass on its own.
    case rateLimited
    /// Sources answered, but the response could not be read.
    case unparseable
    /// The request never reached the sources.
    case unreachable
    /// Sources failed for more than one reason, so no single cause describes it.
    case mixed
}

extension SourceFailureCause {
    /// The one place an error becomes a cause. Both the aggregate fetch and the per-feed fetch
    /// need this verdict, and two copies of it would drift.
    init(_ error: Error) {
        switch error {
        case let newsError as NewsError:
            switch newsError {
            case .sourceTimeout: self = .timedOut
            case .invalidResponse: self = .rejected
            case .rateLimited: self = .rateLimited
            case .parsingFailed: self = .unparseable
            case .networkUnavailable: self = .unreachable
            case .allSourcesFailed(_, let cause): self = cause
            case .cacheFailed: self = .mixed
            }
        case let urlError as URLError:
            switch urlError.code {
            case .timedOut: self = .timedOut
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
                self = .unreachable
            default: self = .mixed
            }
        default:
            self = .mixed
        }
    }
}

enum NewsError: Error, Equatable {
    case networkUnavailable
    /// Every source applicable to the request failed. Carries exactly those sources, so the
    /// reader is never told a source failed that was never attempted, plus why they failed.
    case allSourcesFailed([NewsSource], cause: SourceFailureCause)
    case invalidResponse(statusCode: Int)
    /// The source is rate limiting us. Carries the delay the server asked for, when it stated one.
    case rateLimited(retryAfter: TimeInterval?)
    case sourceTimeout(NewsSource)
    case parsingFailed(NewsSource)
    case cacheFailed
}
