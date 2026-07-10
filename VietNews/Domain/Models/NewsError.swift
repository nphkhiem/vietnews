enum NewsError: Error, Equatable {
    case networkUnavailable
    case invalidResponse(statusCode: Int)
    case sourceTimeout(NewsSource)
    case parsingFailed(NewsSource)
    case cacheFailed
}
