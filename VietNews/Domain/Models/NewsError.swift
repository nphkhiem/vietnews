/// Why every source applicable to a request failed, in terms the interface can turn into copy
/// that suggests what the reader might do next.
enum SourceFailureCause: Equatable, Hashable {
    /// Sources did not answer within their budget.
    case timedOut
    /// Sources answered, but refused the request.
    case rejected
    /// Sources answered, but the response could not be read.
    case unparseable
    /// The request never reached the sources.
    case unreachable
    /// Sources failed for more than one reason, so no single cause describes it.
    case mixed
}

enum NewsError: Error, Equatable {
    case networkUnavailable
    /// Every source applicable to the request failed. Carries exactly those sources, so the
    /// reader is never told a source failed that was never attempted, plus why they failed.
    case allSourcesFailed([NewsSource], cause: SourceFailureCause)
    case invalidResponse(statusCode: Int)
    case sourceTimeout(NewsSource)
    case parsingFailed(NewsSource)
    case cacheFailed
}
