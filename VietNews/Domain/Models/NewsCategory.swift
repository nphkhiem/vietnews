enum NewsCategory: String, CaseIterable, Codable {
    case hotNews, sport, world, finance, work, technology, car, social, game

    func isAvailable(in language: Language) -> Bool {
        switch self {
        case .game: return language == .english
        case .social: return language == .vietnamese
        default: return true
        }
    }
}
