enum NewsSource: String, CaseIterable, Codable {
    case vnexpress, substack, nyt, reuters, reddit, eurogamer

    var displayName: String {
        switch self {
        case .vnexpress: return "VNExpress"
        case .substack: return "Substack"
        case .nyt: return "NY Times"
        case .reuters: return "Reuters"
        case .reddit: return "Reddit"
        case .eurogamer: return "Eurogamer"
        }
    }
}
