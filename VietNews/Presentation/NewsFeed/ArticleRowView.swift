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
                    Text(ArticleTimestampFormatter.string(for: article.publishedAt, language: language))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)

            // Trailing rather than leading, so every headline starts on the same left edge and an
            // article with no image simply lets the text run full width. Leading placement made
            // absence cost either an empty grey square or a ragged left margin.
            if let imageURL = article.imageURL {
                ThumbnailView(url: imageURL, side: 80, loader: thumbnailLoader)
            }
        }
        .padding(.horizontal)
        .contentShape(Rectangle())
    }
}

enum ArticleTimestampFormatter {
    static func string(for date: Date, language: Language, now: Date = Date()) -> String {
        let seconds = now.timeIntervalSince(date)
        let isVietnamese = language == .vietnamese

        if seconds < 3600 {
            let minutes = max(1, Int(seconds / 60))
            return isVietnamese ? "\(minutes) phút trước" : "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
        }

        if seconds < 86400 {
            let hours = Int(seconds / 3600)
            return isVietnamese ? "\(hours) giờ trước" : "\(hours) hour\(hours == 1 ? "" : "s") ago"
        }

        if seconds <= 7 * 86400 {
            let days = Int(seconds / 86400)
            return isVietnamese ? "\(days) ngày trước" : "\(days) day\(days == 1 ? "" : "s") ago"
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yyyy"
        return formatter.string(from: date)
    }
}
