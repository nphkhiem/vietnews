import SwiftUI

/// Articles the reader kept, newest saved first.
///
/// Reads with no connection, because the whole article was stored rather than a reference the
/// app would have to go and resolve again.
struct SavedView: View {
    @ObservedObject var store: SavedArticleStore
    let language: Language
    let thumbnailLoader: ThumbnailLoading

    @State private var presentation: ArticlePresentation?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MastheadView(title: L10n.savedTitle(language))
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Palette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .articlePresentation($presentation)
    }

    @ViewBuilder
    private var content: some View {
        if store.articles.isEmpty {
            // No action button: there is nothing to retry here, and the way out is to go and
            // read something. The copy says how saving works instead.
            ScrollView {
                EmptyStateView(
                    systemImage: "bookmark",
                    message: L10n.savedEmpty(language) + "\n" + L10n.savedEmptyHint(language)
                )
                .padding(.top, Tokens.Space.xxl * 2)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("saved.empty")
            }
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(store.articles.enumerated()), id: \.element.id) { index, article in
                        ArticleRowView(
                            article: article,
                            language: language,
                            isRead: false,
                            accessibilityIdentifier: "saved.row.\(index)",
                            thumbnailLoader: thumbnailLoader,
                            actions: actions(for: article),
                            showsSavedMark: false
                        )
                        Divider().overlay(Tokens.Palette.hairline)
                    }
                }
            }
        }
    }

    /// Removing is offered through the same actions the feed uses, so a long press or an
    /// assistive action both reach it and a swipe is never the only way out.
    private func actions(for article: Article) -> ArticleActionSet {
        ArticleActionSet(
            isSaved: true,
            onToggleSave: { store.remove(id: article.id) },
            onShare: { presentation = .share(article) },
            onOpen: { presentation = .reader(article) }
        )
    }
}
