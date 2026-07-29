import SwiftUI

/// What can be done with an article, passed to whatever is showing it.
///
/// Bundled rather than passed as four separate closures because the row, the lead and the saved
/// list all take the same set, and a nine parameter initializer is its own kind of bug.
struct ArticleActionSet {
    let isSaved: Bool
    let onToggleSave: () -> Void
    let onShare: () -> Void
    let onOpen: () -> Void
}

/// Save, share and open, offered from an article wherever one is shown.
///
/// One modifier rather than a menu written into each of the row, the lead and the saved list,
/// because three copies of the same menu is three places for them to disagree about what an
/// article can do.
///
/// Every action is declared twice on purpose: once as a context menu item for a long press, and
/// once as an accessibility action. A context menu is a gesture, and a reader using VoiceOver or
/// Switch Control does not perform it.
///
/// Applied inside the row rather than around it, because the row collapses itself into a single
/// accessibility element and actions attached from outside that element would not reach it.
struct ArticleActions: ViewModifier {
    let language: Language
    let actions: ArticleActionSet

    private var saveTitle: String {
        actions.isSaved ? L10n.actionUnsave(language) : L10n.actionSave(language)
    }

    func body(content: Content) -> some View {
        content
            .contextMenu {
                // Identified rather than matched on their titles, so a test of the menu does not
                // break when the copy or the language changes.
                Button(
                    saveTitle,
                    systemImage: actions.isSaved ? "bookmark.fill" : "bookmark",
                    action: actions.onToggleSave
                )
                .accessibilityIdentifier("article.action.save")
                Button(
                    L10n.actionShare(language),
                    systemImage: "square.and.arrow.up",
                    action: actions.onShare
                )
                .accessibilityIdentifier("article.action.share")
                Button(L10n.actionOpen(language), systemImage: "safari", action: actions.onOpen)
                    .accessibilityIdentifier("article.action.open")
            }
            .accessibilityAction(named: saveTitle, actions.onToggleSave)
            .accessibilityAction(named: L10n.actionShare(language), actions.onShare)
            .accessibilityAction(named: L10n.actionOpen(language), actions.onOpen)
    }
}

extension View {
    func articleActions(language: Language, actions: ArticleActionSet) -> some View {
        modifier(ArticleActions(language: language, actions: actions))
    }
}

/// The system share sheet.
///
/// Presented by the list rather than built into each row, so there is one sheet on screen at a
/// time instead of one per article, and so the context menu and the accessibility action reach
/// the same code.
struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
