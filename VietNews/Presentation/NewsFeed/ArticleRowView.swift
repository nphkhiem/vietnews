import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let language: Language
    /// Stable handle for UI tests, so a query never depends on localized copy.
    let accessibilityIdentifier: String
    let thumbnailLoader: ThumbnailLoading

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(article.title)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                    .accessibilityIdentifier(accessibilityIdentifier)
                HStack(spacing: 6) {
                    Text(article.source.displayName)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(.secondarySystemBackground)))
                    if let timestamp = ArticleTimestampFormatter.string(
                        for: article.publishedAt,
                        language: language
                    ) {
                        Text(timestamp)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)

            // Trailing rather than leading, so every headline starts on the same left edge and an
            // article with no image simply lets the text run full width. Leading placement made
            // absence cost either an empty grey square or a ragged left margin.
            if let imageURL = article.imageURL {
                ThumbnailView(url: imageURL, side: 80, language: language, loader: thumbnailLoader)
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
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

    /// A fixed dd/MM/yyyy pattern read as a US date to half the world. Asking for a medium date
    /// in the reader's own locale gives each language its own conventional order.
    private static func makeFormatter(for language: Language) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
