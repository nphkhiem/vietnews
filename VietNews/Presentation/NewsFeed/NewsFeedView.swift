import SwiftUI

struct NewsFeedView: View {
    @ObservedObject var viewModel: NewsFeedViewModel
    @State private var presentedArticle: Article?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                CategoryTabBar(
                    categories: NewsCategory.allCases.filter { $0.isAvailable(in: viewModel.language) },
                    selected: viewModel.selectedCategory,
                    language: viewModel.language,
                    onSelect: { category in
                        Task { await viewModel.selectCategory(category) }
                    }
                )
                content
            }
            .navigationTitle("Thông Tấn Xã")
            .navigationBarTitleDisplayMode(.inline)
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
            LazyVStack(spacing: 16) {
                if !viewModel.failedSources.isEmpty {
                    unavailableBanner
                }
                if viewModel.isShowingCachedData, let updated = viewModel.lastUpdated {
                    Text(staleLabel(updated))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(viewModel.articles) { article in
                    ArticleRowView(article: article, language: viewModel.language)
                        .onTapGesture { presentedArticle = article }
                }
            }
            .padding(.vertical, 8)
        }
        .refreshable { await viewModel.refresh() }
    }

    private var unavailableBanner: some View {
        Text(viewModel.language == .vietnamese
             ? "Một số nguồn tin không khả dụng"
             : "Some sources unavailable")
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
            Text(viewModel.language == .vietnamese
                 ? "Không có tin tức trong mục này"
                 : "No articles in this category")
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
            Button(viewModel.language == .vietnamese ? "Thử lại" : "Retry") {
                Task { await viewModel.load() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private func staleLabel(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(
            identifier: viewModel.language == .vietnamese ? "vi_VN" : "en_US"
        )
        let relative = formatter.localizedString(for: date, relativeTo: Date())
        return viewModel.language == .vietnamese
            ? "Cập nhật lần cuối \(relative)"
            : "Last updated \(relative)"
    }
}
