enum NewsError: Error, Equatable {
    case networkUnavailable
    /// Every source applicable to the request failed. Carries exactly those sources, so the
    /// reader is never told a source failed that was never attempted.
    case allSourcesFailed([NewsSource])
    case invalidResponse(statusCode: Int)
    case sourceTimeout(NewsSource)
    case parsingFailed(NewsSource)
    case cacheFailed
}
