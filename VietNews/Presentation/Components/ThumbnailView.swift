import SwiftUI

/// Shows an article thumbnail with three distinct states. `AsyncImage` collapsed loading and
/// failure into one appearance, so a permanently broken image was indistinguishable from one
/// still arriving, and there was no way to ask for it again.
struct ThumbnailView: View {
    let url: URL
    let side: CGFloat
    let language: Language
    let loader: ThumbnailLoading

    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var didFail = false

    var body: some View {
        content
            .frame(width: side, height: side)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .task(id: url) { await load() }
    }

    @ViewBuilder
    private var content: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .accessibilityHidden(true)
        } else if didFail {
            Button {
                Task { await load() }
            } label: {
                ZStack {
                    Color(.secondarySystemBackground)
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.thumbnailRetry(language))
        } else {
            Color(.secondarySystemBackground)
                .accessibilityHidden(true)
        }
    }

    private func load() async {
        didFail = false
        // Ask for the pixels this row actually shows, at this screen's scale.
        let maxPixelSize = Int(side * displayScale)
        do {
            image = try await loader.thumbnail(for: url, maxPixelSize: maxPixelSize)
        } catch {
            guard !Task.isCancelled else { return }
            didFail = true
        }
    }
}
