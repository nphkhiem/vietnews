import SwiftUI

struct NewsFeedView: View {
    @ObservedObject var viewModel: NewsFeedViewModel
    @State private var presentedArticle: Article?
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
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Palette.background)
            // The stock bar is replaced by the masthead rather than restyled, so it is hidden
            // outright. The stack stays because later work pushes from here.
            .toolbar(.hidden, for: .navigationBar)
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
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .loading:
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(0..<8, id: \.self) { _ in SkeletonRowView() }
                }
                .padding(.top, 8)
            }
        case .empty:
            emptyState
        case .failed(let message):
            failedState(message)
        case .loaded:
            articleList
        }
    }

    private var articleList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if let message = viewModel.refreshFailureMessage {
                    refreshFailureBanner(message)
                }
                if !viewModel.failedSources.isEmpty {
                    unavailableBanner
                }
                if viewModel.isShowingStaleData, let updated = viewModel.lastUpdated {
                    Text(staleLabel(updated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
                            onOpen: { open(article) }
                        )
                    } else {
                        ArticleRowView(
                            article: article,
                            language: viewModel.language,
                            isRead: viewModel.readArticleIDs.contains(article.id),
                            accessibilityIdentifier: "feed.row.\(article.category.rawValue).\(index)",
                            thumbnailLoader: viewModel.thumbnailLoader,
                            onOpen: { open(article) }
                        )
                    }
                    Divider()
                        .overlay(Tokens.Palette.hairline)
                }
            }
        }
        .refreshable { await viewModel.refresh() }
    }

    private func open(_ article: Article) {
        viewModel.markRead(article)
        presentedArticle = article
    }

    private func refreshFailureBanner(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal)
            .background(Color(.secondarySystemBackground))
    }

    private var unavailableBanner: some View {
        Text(L10n.feedSourcesUnavailable(viewModel.language))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "newspaper")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(L10n.feedEmpty(viewModel.language))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func failedState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "wifi.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(L10n.feedRetry(viewModel.language)) {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private func staleLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = viewModel.language.locale
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return L10n.feedLastUpdated(viewModel.language, relative)
    }
}
