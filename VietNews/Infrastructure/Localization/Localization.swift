import Foundation

/// Every user-facing string in the app, keyed by its entry in `Localizable.strings`.
///
/// Adding a language is now a matter of adding an `.lproj` folder. Adding a string means adding
/// a case here and a line to each table, which fails loudly in tests if a translation is missing
/// rather than silently falling back to the key.
enum L10n: String, CaseIterable {
    case appName = "app.name"
    case tabFeed = "tab.feed"
    case tabSettings = "tab.settings"

    case bannerOffline = "banner.offline"
    case feedSourcesUnavailable = "feed.sourcesUnavailable"
    case feedSourcesUnavailableNamed = "feed.sourcesUnavailableNamed"
    case feedEmptyHint = "feed.emptyHint"
    case feedEmpty = "feed.empty"
    case feedRetry = "feed.retry"
    case feedLastUpdated = "feed.lastUpdated"

    case errorOffline = "error.offline"
    case errorTimedOut = "error.timedOut"
    case errorRejected = "error.rejected"
    case errorRateLimited = "error.rateLimited"
    case errorUnparseable = "error.unparseable"
    case errorUnreachable = "error.unreachable"
    case errorGeneric = "error.generic"

    case timeJustNow = "time.justNow"

    case settingsTitle = "settings.title"
    case settingsSectionLanguage = "settings.section.language"
    case settingsSectionAutoRefresh = "settings.section.autoRefresh"
    case settingsSectionMaxArticles = "settings.section.maxArticles"
    case settingsSectionSubstack = "settings.section.substack"
    case settingsMaxArticlesLabel = "settings.maxArticles.label"
    case settingsSubstackURLPlaceholder = "settings.substack.urlPlaceholder"
    case settingsCategory = "settings.category"
    case settingsAdd = "settings.add"
    case settingsInvalidURLTitle = "settings.invalidURL.title"

    case categoryHotNews = "category.hotNews"
    case categorySport = "category.sport"
    case categoryWorld = "category.world"
    case categoryFinance = "category.finance"
    case categoryWork = "category.work"
    case categoryTechnology = "category.technology"
    case categoryCar = "category.car"
    case categorySocial = "category.social"
    case categoryGame = "category.game"

    case articleRead = "article.read"
    case thumbnailRetry = "thumbnail.retry"

    func callAsFunction(_ language: Language) -> String {
        Localization.string(self, language: language)
    }

    /// For strings taking a substituted value, such as a formatted relative date.
    func callAsFunction(_ language: Language, _ value: String) -> String {
        String(format: Localization.string(self, language: language), locale: language.locale, value)
    }
}

/// Counted strings live in `Localizable.stringsdict`, so the plural rule belongs to the language
/// rather than to a conditional in Swift. English inflects and Vietnamese does not, and neither
/// call site needs to know that.
enum L10nPlural: String {
    case minutesAgo = "time.minutesAgo"
    case hoursAgo = "time.hoursAgo"
    case daysAgo = "time.daysAgo"
    case settingsInterval = "settings.interval"

    func callAsFunction(_ language: Language, count: Int) -> String {
        String(format: Localization.string(rawValue, language: language), locale: language.locale, count)
    }
}

enum Localization {
    static func string(_ key: L10n, language: Language) -> String {
        string(key.rawValue, language: language)
    }

    static func string(_ key: String, language: Language) -> String {
        // `value:` is deliberately the key itself: a missing translation then shows the key,
        // which is obvious in a screenshot and detectable in a test, rather than silently
        // falling back to the development language and looking correct.
        bundle(for: language).localizedString(forKey: key, value: key, table: nil)
    }

    /// The reader's chosen language overrides the system locale, so strings are resolved against
    /// that language's bundle rather than through `Bundle.main`, which would follow the device.
    private static func bundle(for language: Language) -> Bundle {
        if let cached = cachedBundles[language] {
            return cached
        }
        guard
            let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else {
            return .main
        }
        cachedBundles[language] = bundle
        return bundle
    }

    private static var cachedBundles: [Language: Bundle] = [:]
}

extension Language {
    /// One place deriving a locale from the chosen language, for dates and number formatting.
    var locale: Locale {
        switch self {
        case .vietnamese: return Locale(identifier: "vi_VN")
        case .english: return Locale(identifier: "en_US")
        }
    }
}
