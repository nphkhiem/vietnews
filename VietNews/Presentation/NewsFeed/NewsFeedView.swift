import SwiftUI

struct NewsFeedView: View {
    @ObservedObject var viewModel: NewsFeedViewModel
    /// Passed in rather than observed here, so connectivity has one owner and the feed simply
    /// renders what it is told.
    let isOffline: Bool
    /// Built here rather than passed in, so the banner's route to Sources needs nothing from the
    /// feed's own view model.
    let makeSourcesViewModel: (Language) -> SourcesViewModel
    @ObservedObject var savedArticles: SavedArticleStore
    @State private var presentedArticle: Article?
    /// One share sheet for the list rather than one per row, so the context menu and the
    /// accessibility action both reach the same presentation.
    @State private var sharedArticle: Article?
    @State private var isShowingSources = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Fixed furniture: the masthead and the strip do not scroll away with the news.
                MastheadView(title: L10n.appName(viewModel.language))
                CategoryStrip(
                    categories: NewsCategory.allCases.filter { $0.isAvailable(in: viewModel.language) },
                    selected: viewModel.selectedCategory,
                    language: viewModel.language,
                    onSelect: { category in
                        Task { await viewModel.selectCategory(category) }
                    }
                )
                // Fixed above the news rather than scrolled with it. A reader who is offline or
                // missing sources needs that before they start reading, not when they happen to
                // scroll back to the top.
                banners
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Palette.background)
            // The stock bar is replaced by the masthead rather than restyled, so it is hidden
            // outright. The stack stays because the banner pushes Sources from here.
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $isShowingSources) {
                SourcesView(language: viewModel.language) {
                    makeSourcesViewModel(viewModel.language)
                }
            }
        }
        .task { await viewModel.start() }
        .onChange(of: scenePhase) { phase in
            switch phase {
            case .background:
                viewModel.stop()
            case .active:
                Task { await viewModel.start() }
            default:
                break
            }
        }
        .sheet(item: $presentedArticle) { article in
            SafariView(url: article.url)
                .ignoresSafeArea()
        }
        .sheet(item: $sharedArticle) { article in
            ShareSheet(url: article.url)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(0..<8, id: \.self) { _ in SkeletonRowView() }
                }
                .padding(.top, Tokens.Space.s)
            }
            // The placeholders are hidden individually, so the state announces itself once here
            // rather than as eight empty items.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.feedLoading(viewModel.language))
        case .empty:
            recoverableState(
                icon: "newspaper",
                message: L10n.feedEmpty(viewModel.language) + "\n" + L10n.feedEmptyHint(viewModel.language)
            )
        case .failed(let message):
            recoverableState(icon: "wifi.exclamationmark", message: message)
        case .loaded:
            articleList
        }
    }

    @ViewBuilder
    private var banners: some View {
        // Connectivity first: when the device is offline, that explains everything below it and
        // no other message adds anything.
        if isOffline {
            StatusBanner(
                severity: .caution,
                message: L10n.bannerOffline(viewModel.language),
                detail: viewModel.lastUpdated.map { staleLabel($0) }
            )
        } else {
            if let message = viewModel.refreshFailureMessage {
                StatusBanner(severity: .problem, message: message)
            }
            if !viewModel.failedSources.isEmpty {
                // The reader meets the problem and can act on it in the same breath. This is the
                // same screen Settings reaches, not a second one, so nothing has two homes.
                StatusBanner(
                    severity: .problem,
                    message: unavailableMessage,
                    actionTitle: L10n.sourcesManage(viewModel.language),
                    action: { isShowingSources = true }
                )
            }
            if viewModel.isShowingStaleData, let updated = viewModel.lastUpdated {
                StatusBanner(severity: .caution, message: staleLabel(updated))
            }
        }
    }

    /// Names the sources rather than saying "some sources", so the reader knows what they are
    /// missing. The list is joined the way the reader's own language joins lists.
    private var unavailableMessage: String {
        let names = viewModel.failedSources.map(\.displayName)
        let formatter = ListFormatter()
        formatter.locale = viewModel.language.locale
        guard let joined = formatter.string(from: names), !names.isEmpty else {
            return L10n.feedSourcesUnavailable(viewModel.language)
        }
        return L10n.feedSourcesUnavailableNamed(viewModel.language, joined)
    }

    private var articleList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(viewModel.articles.enumerated()), id: \.element.id) { index, article in
                    // The first article carries the category. Everything below it is uniform, so
                    // the eye has exactly one place to land.
                    if index == 0 {
                        LeadStoryView(
                            article: article,
                            language: viewModel.language,
                            isRead: viewModel.readArticleIDs.contains(article.id),
                            accessibilityIdentifier: "feed.row.\(article.category.rawValue).\(index)",
                            thumbnailLoader: viewModel.thumbnailLoader,
                            actions: actions(for: article)
                        )
                    } else {
                        ArticleRowView(
                            article: article,
                            language: viewModel.language,
                            isRead: viewModel.readArticleIDs.contains(article.id),
                            accessibilityIdentifier: "feed.row.\(article.category.rawValue).\(index)",
                            thumbnailLoader: viewModel.thumbnailLoader,
                            actions: actions(for: article)
                        )
                    }
                    Divider()
                        .overlay(Tokens.Palette.hairline)
                }
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    /// Saving from the feed never opens the article, which is the point: keeping something for
    /// later should not cost the reader their place in the list.
    private func actions(for article: Article) -> ArticleActionSet {
        ArticleActionSet(
            isSaved: savedArticles.isSaved(article.id),
            onToggleSave: { savedArticles.toggle(article) },
            onShare: { sharedArticle = article },
            onOpen: { open(article) }
        )
    }

    private func open(_ article: Article) {
        viewModel.markRead(article)
        presentedArticle = article
    }

    /// Both states are scrollable so pull to refresh works from them. Previously each was a
    /// fixed stack, so a reader who reached one had no way out except changing category.
    private func recoverableState(icon: String, message: String) -> some View {
        ScrollView {
            EmptyStateView(
                systemImage: icon,
                message: message,
                actionTitle: L10n.feedRetry(viewModel.language),
                action: { Task { await viewModel.load() } }
            )
            .padding(.top, Tokens.Space.xxl * 2)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func staleLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = viewModel.language.locale
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return L10n.feedLastUpdated(viewModel.language, relative)
    }
}
