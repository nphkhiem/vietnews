import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let language: Language
    /// Stable handle for UI tests, so a query never depends on localized copy.
    let accessibilityIdentifier: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncImage(url: article.imageURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    ZStack {
                        Color(.secondarySystemBackground)
                        Image(systemName: "newspaper")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))

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
        let isVietnamese = language == .vietnamese

        if seconds < 0 {
            guard -seconds <= futureTolerance else { return nil }
            return isVietnamese ? "Vừa xong" : "Just now"
        }

        if seconds < 60 {
            return isVietnamese ? "Vừa xong" : "Just now"
        }

        if seconds < 3600 {
            let minutes = Int(seconds / 60)
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

        return absoluteFormatter(for: language).string(from: date)
    }

    /// Built once per language. These were previously constructed on every row for every redraw,
    /// and `DateFormatter` is one of the more expensive objects in Foundation to create.
    private static let vietnameseFormatter = makeFormatter(localeIdentifier: "vi_VN")
    private static let englishFormatter = makeFormatter(localeIdentifier: "en_US")

    private static func absoluteFormatter(for language: Language) -> DateFormatter {
        language == .vietnamese ? vietnameseFormatter : englishFormatter
    }

    /// A fixed dd/MM/yyyy pattern read as a US date to half the world. Asking for a medium date
    /// in the reader's own locale gives each language its own conventional order.
    private static func makeFormatter(localeIdentifier: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: localeIdentifier)
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}
