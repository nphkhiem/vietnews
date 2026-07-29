import SwiftUI

/// Finding an article the reader remembers, without scrolling for it.
struct SearchView: View {
    @StateObject private var viewModel: SearchViewModel
    let language: Language
    let thumbnailLoader: ThumbnailLoading
    let savedArticles: SavedArticleStore

    @State private var presentation: ArticlePresentation?
    @FocusState private var queryFocused: Bool
    @Environment(\.dismiss) private var dismiss

    init(
        language: Language,
        thumbnailLoader: ThumbnailLoading,
        savedArticles: SavedArticleStore,
        makeViewModel: @escaping () -> SearchViewModel
    ) {
        self.language = language
        self.thumbnailLoader = thumbnailLoader
        self.savedArticles = savedArticles
        _viewModel = StateObject(wrappedValue: makeViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            MastheadView(
                title: L10n.searchTitle(language),
                leading: .back(label: L10n.commonBack(language)) { dismiss() }
            )
            field
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Tokens.Palette.background)
        .toolbar(.hidden, for: .navigationBar)
        .articlePresentation($presentation)
        .onAppear {
            viewModel.load()
            queryFocused = true
        }
    }

    private var field: some View {
        HStack(spacing: Tokens.Space.s) {
            Image(systemName: "magnifyingglass")
                .font(Tokens.Typography.category)
                .foregroundStyle(Tokens.Palette.inkTertiary)
                .accessibilityHidden(true)

            TextField(L10n.searchPlaceholder(language), text: $viewModel.query)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($queryFocused)
                .font(Tokens.Typography.category)
                .accessibilityIdentifier("search.field")
        }
        .padding(Tokens.Space.m)
        .background(Tokens.Palette.surface)
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.image))
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.m)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.query.trimmingCharacters(in: .whitespaces).isEmpty {
            hint(L10n.searchHint(language, "\(viewModel.corpus.count)"))
        } else if viewModel.results.isEmpty {
            // "No matches" rather than an error. Nothing went wrong; there is simply nothing
            // here by that name.
            hint(L10n.searchNoMatches(language))
                .accessibilityIdentifier("search.noMatches")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.element.id) { index, article in
                        ArticleRowView(
                            article: article,
                            language: language,
                            isRead: false,
                            accessibilityIdentifier: "search.row.\(index)",
                            thumbnailLoader: thumbnailLoader,
                            actions: actions(for: article),
                            highlight: viewModel.query.trimmingCharacters(in: .whitespaces)
                        )
                        Divider().overlay(Tokens.Palette.hairline)
                    }
                }
            }
        }
    }

    private func hint(_ message: String) -> some View {
        VStack {
            Text(message)
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Tokens.Space.xxl)
                .padding(.top, Tokens.Space.xxl)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func actions(for article: Article) -> ArticleActionSet {
        ArticleActionSet(
            isSaved: savedArticles.isSaved(article.id),
            onToggleSave: { savedArticles.toggle(article) },
            onShare: { presentation = .share(article) },
            onOpen: { presentation = .reader(article) }
        )
    }
}
