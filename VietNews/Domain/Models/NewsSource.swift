enum NewsSource: String, CaseIterable, Codable {
    case vnexpress, substack, nyt, bbc, reddit, eurogamer

    var displayName: String {
        switch self {
        case .vnexpress: return "VNExpress"
        case .substack: return "Substack"
        case .nyt: return "NY Times"
        case .bbc: return "BBC News"
        case .reddit: return "Reddit"
        case .eurogamer: return "Eurogamer"
        }
    }
}
