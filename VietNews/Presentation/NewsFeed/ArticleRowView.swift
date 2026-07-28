import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let language: Language
    let isRead: Bool
    /// Stable handle for UI tests, so a query never depends on localized copy.
    let accessibilityIdentifier: String
    let thumbnailLoader: ThumbnailLoading
    let onOpen: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: Tokens.Space.xs + 1) {
                // The image sits beside the source line and headline only. Running it down the
                // whole row narrowed the summary for its entire height and left a ragged notch
                // to its right once the image ended.
                HStack(alignment: .top, spacing: Tokens.Space.m) {
                    if let imageURL = article.imageURL, !hidesThumbnail {
                        ThumbnailView(
                            url: imageURL,
                            side: thumbnailSide,
                            language: language,
                            loader: thumbnailLoader
                        )
                    }

                    VStack(alignment: .leading, spacing: Tokens.Space.xs + 1) {
                        sourceLine
                        headline
                    }
                    Spacer(minLength: 0)
                }

                // Full width, so it gets a proper measure rather than being clipped early by
                // the image beside it.
                summary
            }
            .padding(.horizontal, Tokens.Space.l)
            .padding(.vertical, Tokens.Space.m)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // One element rather than four, so VoiceOver reads the row as an article and can open
        // it. Previously the row exposed no action at all, which left the app's main
        // interaction unavailable to anyone using it.
        .accessibilityElement(children: .ignore)
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var sourceLine: some View {
        HStack(spacing: Tokens.Space.s) {
            // Uppercase and tracked, so a source is recognisable by its shape before it is read
            // and is never distinguished by colour alone.
            Text(article.source.displayName.uppercased())
                .font(Tokens.Typography.meta)
                .tracking(0.8)
                .foregroundStyle(isRead ? Tokens.Palette.inkTertiary : Tokens.Palette.source(article.source))

            if let timestamp = ArticleTimestampFormatter.string(for: article.publishedAt, language: language) {
                Text(verbatim: "·")
                    .font(Tokens.Typography.meta)
                    .foregroundStyle(Tokens.Palette.inkTertiary)
                Text(timestamp)
                    .font(Tokens.Typography.meta.weight(.regular))
                    .foregroundStyle(Tokens.Palette.inkTertiary)
            }
        }
    }

    // A read headline changes colour only. Nothing moves, so a refreshed feed does not reflow
    // under the reader.
    private var headline: some View {
        Text(article.title)
            .font(Tokens.Typography.headline)
            .lineSpacing(Tokens.Layout.headlineLineSpacing)
            .foregroundStyle(isRead ? Tokens.Palette.inkRead : Tokens.Palette.ink)
            .lineLimit(headlineLineLimit)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var summary: some View {
        let text = article.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            Text(text)
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
                .lineLimit(summaryLineLimit)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// At accessibility sizes the headline gains lines rather than truncating mid phrase, and the
    /// summary steps back so a single article does not fill the whole screen.
    ///
    /// Beside an image the headline stops at two lines, which is where the image ends. A third
    /// line would sit alone in the narrowed column with empty space to its right, because text
    /// cannot flow back around the image once it clears it. Without an image there is no column
    /// to escape and the headline gets its third line.
    private var headlineLineLimit: Int {
        if dynamicTypeSize.isAccessibilitySize { return 6 }
        return showsThumbnail ? 2 : 3
    }

    private var summaryLineLimit: Int {
        dynamicTypeSize.isAccessibilitySize ? 1 : 2
    }

    /// The thumbnail grows with text so it keeps its relationship to the headline beside it, and
    /// drops out entirely at accessibility sizes where the words need the full width.
    private var thumbnailSide: CGFloat {
        dynamicTypeSize >= .xxLarge ? Tokens.Layout.thumbnailSide * 1.25 : Tokens.Layout.thumbnailSide
    }

    private var hidesThumbnail: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var showsThumbnail: Bool {
        article.imageURL != nil && !hidesThumbnail
    }

    /// Reads as one sentence: what it is, who published it, when, and whether it has been opened.
    private var accessibilityLabel: String {
        var parts = [article.title, article.source.displayName]
        if let timestamp = ArticleTimestampFormatter.string(for: article.publishedAt, language: language) {
            parts.append(timestamp)
        }
        if isRead {
            parts.append(L10n.articleRead(language))
        }
        return parts.joined(separator: ", ")
    }
}

enum ArticleTimestampFormatter {
    /// Feeds are routinely a little ahead of the device clock, so a small lead is treated as
    /// "just now" rather than as a broken date. Beyond that the date is not believable and
    /// nothing is shown, which is the same treatment a missing date gets.
    private static let futureTolerance: TimeInterval = 120

    /// Returns nil when there is no date worth showing, so the caller can omit the element
    /// entirely instead of printing a placeholder.
    static func string(for date: Date?, language: Language, now: Date = Date()) -> String? {
        guard let date else { return nil }

        let seconds = now.timeIntervalSince(date)

        if seconds < 0 {
            guard -seconds <= futureTolerance else { return nil }
            return L10n.timeJustNow(language)
        }

        if seconds < 60 {
            return L10n.timeJustNow(language)
        }

        if seconds < 3600 {
            return L10nPlural.minutesAgo(language, count: Int(seconds / 60))
        }

        if seconds < 86400 {
            return L10nPlural.hoursAgo(language, count: Int(seconds / 3600))
        }

        if seconds <= 7 * 86400 {
            return L10nPlural.daysAgo(language, count: Int(seconds / 86400))
        }

        return absoluteFormatter(for: language).string(from: date)
    }

    /// Built once per language. These were previously constructed on every row for every redraw,
    /// and `DateFormatter` is one of the more expensive objects in Foundation to create.
    private static let vietnameseFormatter = makeFormatter(for: .vietnamese)
    private static let englishFormatter = makeFormatter(for: .english)

    private static func absoluteFormatter(for language: Language) -> DateFormatter {
        switch language {
        case .vietnamese: return vietnameseFormatter
        case .english: return englishFormatter
        }
    }

    /// A fixed dd/MM/yyyy pattern reads as a US date to half the world. Asking for a medium date
    /// in the reader's own locale gives each language its own conventional order.
    private static func makeFormatter(for language: Language) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
