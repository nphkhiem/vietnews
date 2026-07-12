import Factory
import Foundation

extension Container {
    var networkService: Factory<NetworkService> {
        self {
            URLCache.shared = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
            return URLSessionNetworkService()
        }.singleton
    }

    var userPreferences: Factory<UserPreferences> {
        self { UserPreferences() }.singleton
    }

    var vnexpressSource: Factory<NewsSourceAdapter> {
        self { VNExpressSource.make(network: self.networkService(), parser: FeedKitRSSParser(parsingSource: .vnexpress)) }
    }

    var reutersSource: Factory<NewsSourceAdapter> {
        self { ReutersSource.make(network: self.networkService(), parser: FeedKitRSSParser(parsingSource: .reuters)) }
    }

    var substackSource: Factory<NewsSourceAdapter> {
        self {
            SubstackSource(
                network: self.networkService(),
                parser: FeedKitRSSParser(parsingSource: .substack),
                feeds: { self.userPreferences().substackFeeds }
            )
        }
    }

    var redditSource: Factory<NewsSourceAdapter> {
        self { RedditSource(network: self.networkService()) }
    }

    var nytSource: Factory<NewsSourceAdapter> {
        self {
            let apiKey = Bundle.main.object(forInfoDictionaryKey: "NYT_API_KEY") as? String ?? ""
            return NYTSource(network: self.networkService(), apiKey: apiKey)
        }
    }

    var eurogamerSource: Factory<NewsSourceAdapter> {
        self { EurogamerSource.make(network: self.networkService(), parser: FeedKitRSSParser(parsingSource: .eurogamer)) }
    }

    var newsSourceAdapters: Factory<[NewsSourceAdapter]> {
        self {
            [
                self.vnexpressSource(), self.reutersSource(), self.substackSource(),
                self.redditSource(), self.nytSource(), self.eurogamerSource()
            ]
        }
    }

    var articleRepository: Factory<ArticleRepository> {
        self {
            RemoteArticleRepository(
                adapters: self.newsSourceAdapters(),
                maxArticles: { self.userPreferences().maxArticles }
            )
        }.singleton
    }

    var cacheRepository: Factory<CacheRepository> {
        self { DiskCacheRepository(directory: DiskCacheRepository.defaultDirectory()) }.singleton
    }

    var refreshScheduler: Factory<RefreshScheduling> {
        self { AutoRefreshScheduler() }.singleton
    }

    var networkMonitor: Factory<NetworkMonitor> {
        self { NetworkMonitor() }.singleton
    }

    var fetchNewsUseCase: Factory<FetchNewsUseCase> {
        self { FetchNewsUseCase(articleRepository: self.articleRepository(), cacheRepository: self.cacheRepository()) }
    }

    var refreshNewsUseCase: Factory<RefreshNewsUseCase> {
        self { RefreshNewsUseCase(articleRepository: self.articleRepository(), cacheRepository: self.cacheRepository()) }
    }

    @MainActor
    var newsFeedViewModel: Factory<NewsFeedViewModel> {
        self {
            NewsFeedViewModel(
                fetchNews: self.fetchNewsUseCase(),
                refreshNews: self.refreshNewsUseCase(),
                cacheRepository: self.cacheRepository(),
                preferences: self.userPreferences(),
                scheduler: self.refreshScheduler()
            )
        }.singleton
    }

    @MainActor
    var settingsViewModel: Factory<SettingsViewModel> {
        self {
            SettingsViewModel(
                preferences: self.userPreferences(),
                scheduler: self.refreshScheduler(),
                cacheRepository: self.cacheRepository()
            )
        }.singleton
    }
}
