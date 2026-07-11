import SwiftUI

struct ArticleRowView: View {
    let article: Article
    let language: Language

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
