import Factory
import Foundation

extension Container {
    var networkService: Factory<NetworkService> {
        self { RetryingNetworkService(wrapping: URLSessionNetworkService()) }.singleton
    }

    var thumbnailLoader: Factory<ThumbnailLoading> {
        self { ThumbnailLoader(network: self.networkService()) }.singleton
    }

    var userPreferences: Factory<UserPreferences> {
        self { UserPreferences() }.singleton
    }

    var vnexpressSource: Factory<NewsSourceAdapter> {
        self { VNExpressSource.make(network: self.networkService(), parser: FeedKitRSSParser(parsingSource: .vnexpress)) }
    }

    var bbcSource: Factory<NewsSourceAdapter> {
        self { BBCSource.make(network: self.networkService(), parser: FeedKitRSSParser(parsingSource: .bbc)) }
    }

    var sourceHealthRepository: Factory<SourceHealthRepository> {
        self { DefaultsSourceHealthRepository() }.singleton
    }

    var substackSource: Factory<NewsSourceAdapter> {
        self {
            SubstackSource(
                network: self.networkService(),
                parser: FeedKitRSSParser(parsingSource: .substack),
                feeds: { self.userPreferences().substackFeeds },
                health: self.sourceHealthRepository()
            )
        }
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
                self.vnexpressSource(), self.bbcSource(), self.substackSource(),
                self.nytSource(), self.eurogamerSource()
            ]
        }
    }

    /// What each source covers, answered by the adapters themselves. The sources screen needs
    /// this to say what turning a source off would cost, and deriving it here means the screen
    /// cannot claim a coverage the fetch does not have.
    var sourceCoverage: Factory<(NewsSource, NewsCategory) -> Bool> {
        self {
            let adapters = self.newsSourceAdapters()
            return { source, category in
                guard let adapter = adapters.first(where: { $0.source == source }) else { return false }
                return Language.allCases.contains {
                    adapter.supports(category: category, language: $0)
                }
            }
        }
    }

    var articleRepository: Factory<ArticleRepository> {
        self {
            RemoteArticleRepository(
                adapters: self.newsSourceAdapters(),
                maxArticles: { self.userPreferences().maxArticles },
                health: self.sourceHealthRepository()
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
        self {
            FetchNewsUseCase(
                articleRepository: self.articleRepository(),
                cacheRepository: self.cacheRepository(),
                articleLimit: { self.userPreferences().maxArticles }
            )
        }
    }

    var refreshNewsUseCase: Factory<RefreshNewsUseCase> {
        self {
            RefreshNewsUseCase(
                articleRepository: self.articleRepository(),
                cacheRepository: self.cacheRepository(),
                articleLimit: { self.userPreferences().maxArticles }
            )
        }
    }

    @MainActor
    var newsFeedViewModel: Factory<NewsFeedViewModel> {
        self {
            NewsFeedViewModel(
                fetchNews: self.fetchNewsUseCase(),
                refreshNews: self.refreshNewsUseCase(),
                preferences: self.userPreferences(),
                scheduler: self.refreshScheduler(),
                thumbnailLoader: self.thumbnailLoader(),
                isOnline: { [monitor = self.networkMonitor()] in monitor.isOnline }
            )
        }.singleton
    }

    @MainActor
    var settingsViewModel: Factory<SettingsViewModel> {
        self {
            SettingsViewModel(
                preferences: self.userPreferences(),
                scheduler: self.refreshScheduler(),
                cacheRepository: self.cacheRepository(),
                sourceHealth: self.sourceHealthRepository(),
                serves: self.sourceCoverage()
            )
        }.singleton
    }
}
