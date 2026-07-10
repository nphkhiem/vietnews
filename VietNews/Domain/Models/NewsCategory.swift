enum NewsCategory: String, CaseIterable, Codable {
    case sport, hotNews, world, finance, work, technology, car, social, game

    func displayName(in language: Language) -> String {
        switch (self, language) {
        case (.sport, .english): return "Sport"
        case (.sport, .vietnamese): return "Thể thao"
        case (.hotNews, .english): return "Hot News"
        case (.hotNews, .vietnamese): return "Tin nóng"
        case (.world, .english): return "World"
        case (.world, .vietnamese): return "Thế giới"
        case (.finance, .english): return "Finance"
        case (.finance, .vietnamese): return "Kinh doanh"
        case (.work, .english): return "Work"
        case (.work, .vietnamese): return "Đời sống"
        case (.technology, .english): return "Technology"
        case (.technology, .vietnamese): return "Công nghệ"
        case (.car, .english): return "Car"
        case (.car, .vietnamese): return "Xe"
        case (.social, .english): return "Social"
        case (.social, .vietnamese): return "Góc nhìn"
        case (.game, .english): return "Game"
        case (.game, .vietnamese): return "Trò chơi"
        }
    }
}
