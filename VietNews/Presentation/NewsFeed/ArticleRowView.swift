import SwiftUI

struct ArticleRowView: View {
    let article: Article

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
                    Text(article.publishedAt, style: .relative)
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
