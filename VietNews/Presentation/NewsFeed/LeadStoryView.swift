import SwiftUI

/// The first article in a category, given the weight of a front page.
///
/// It exists so a three second scan has somewhere to land. Every other row is deliberately
/// uniform, and a screen where everything is emphasised says nothing.
struct LeadStoryView: View {
    let article: Article
    let language: Language
    let isRead: Bool
    let accessibilityIdentifier: String
    let thumbnailLoader: ThumbnailLoading
    let actions: ArticleActionSet

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// An image that cannot be loaded is treated exactly like an article that never had one, so
    /// the lead falls back to its text-forward composition rather than showing an empty band.
    @State private var imageFailed = false

    private var showsImage: Bool { article.imageURL != nil && !imageFailed }

    var body: some View {
        Button(action: actions.onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                if let imageURL = article.imageURL, !imageFailed {
                    // Full bleed, and 16:9 because that is the ratio the sources publish, so
                    // nothing is cropped awkwardly. Deliberately the one element that does not
                    // scale with text: cropping news photography to fit type is worse than
                    // letting it keep its shape.
                    LeadImageView(
                        url: imageURL,
                        loader: thumbnailLoader,
                        onFailure: { imageFailed = true }
                    )
                    .padding(.bottom, Tokens.Space.m)
                }

                VStack(alignment: .leading, spacing: Tokens.Space.xs + 1) {
                    SourceLine(article: article, language: language, isRead: isRead, isSaved: actions.isSaved)

                    Text(article.title)
                        .font(Tokens.Typography.lead)
                        .lineSpacing(Tokens.Layout.headlineLineSpacing)
                        .foregroundStyle(isRead ? Tokens.Palette.inkRead : Tokens.Palette.ink)
                        .lineLimit(headlineLineLimit)
                        .fixedSize(horizontal: false, vertical: true)

                    summary
                }
                .padding(.horizontal, Tokens.Space.l)
            }
            .padding(.top, showsImage ? 0 : Tokens.Space.l)
            .padding(.bottom, Tokens.Space.l)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(ArticleAccessibility.label(for: article, language: language, isRead: isRead))
        .accessibilityAddTraits(.isButton)
        .articleActions(language: language, actions: actions)
    }

    @ViewBuilder
    private var summary: some View {
        let text = article.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            Text(text)
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Without an image the headline carries the weight the photograph would have, which is what
    /// keeps the lead position meaningful rather than leaving a hole where a picture should be.
    private var headlineLineLimit: Int {
        if dynamicTypeSize.isAccessibilitySize { return 8 }
        return showsImage ? 3 : 4
    }
}

/// The lead's image. Separate from `ThumbnailView` because it is full bleed, keeps a fixed
/// aspect ratio rather than a square, and asks for a much larger rendition.
private struct LeadImageView: View {
    let url: URL
    let loader: ThumbnailLoading
    let onFailure: () -> Void

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            content(width: proxy.size.width)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipped()
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func content(width: CGFloat) -> some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Tokens.Palette.surface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .task(id: url) { await load(width: width) }
    }

    private func load(width: CGFloat) async {
        let pixels = Int(max(width, 1) * displayScale)
        do {
            image = try await loader.thumbnail(for: url, maxPixelSize: pixels)
        } catch {
            guard !Task.isCancelled else { return }
            onFailure()
        }
    }
}
