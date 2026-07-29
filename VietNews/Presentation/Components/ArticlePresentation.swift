import SwiftUI

/// What a list is currently showing over itself for one article.
///
/// A single value rather than one `@State` per destination, because two `.sheet` modifiers on
/// the same view is not a supported arrangement: SwiftUI honours one of them and the behaviour
/// of the other is undefined.
enum ArticlePresentation: Identifiable {
    case reader(Article)
    case share(Article)

    var article: Article {
        switch self {
        case .reader(let article), .share(let article): return article
        }
    }

    /// Carries which destination it is, so switching from reading an article to sharing the same
    /// one is seen as a change rather than as the same presentation.
    var id: String {
        switch self {
        case .reader(let article): return "reader:\(article.id)"
        case .share(let article): return "share:\(article.id)"
        }
    }
}

extension View {
    /// Presents whichever destination an article list has asked for.
    func articlePresentation(_ presentation: Binding<ArticlePresentation?>) -> some View {
        sheet(item: presentation) { destination in
            switch destination {
            case .reader(let article):
                SafariView(url: article.url)
                    .ignoresSafeArea()
            case .share(let article):
                ShareSheet(url: article.url)
            }
        }
    }
}
