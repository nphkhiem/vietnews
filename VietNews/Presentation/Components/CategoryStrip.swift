import SwiftUI

/// Category navigation, rebuilt from tokens.
///
/// Replaces a filled pill drawn in `Color.accentColor`, which was the system blue and therefore
/// the only accent a reader ever saw on the feed. Selection is now carried by the token accent
/// as an underline, which leaves the accent free to mean the same thing everywhere else.
struct CategoryStrip: View {
    let categories: [NewsCategory]
    let selected: NewsCategory
    let language: Language
    let onSelect: (NewsCategory) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Tokens.Space.xl) {
                    ForEach(categories, id: \.self) { category in
                        item(for: category)
                    }
                }
                .padding(.horizontal, Tokens.Space.l)
            }
            // An edge fade says there is more to the side. Before this a label was simply sliced
            // in half at the boundary, which reads as a rendering fault rather than an
            // invitation to scroll.
            .overlay(alignment: .trailing) { edgeFade }
            .background(Tokens.Palette.background)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Tokens.Palette.hairline)
                    .frame(height: 1)
            }
            .onChange(of: selected) { newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
        // The label still grows with the reader's text size, but not without limit. Uncapped it
        // produced a single pill wider than the screen with the next label cut in half.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private func item(for category: NewsCategory) -> some View {
        let isSelected = category == selected

        return Button {
            onSelect(category)
        } label: {
            Text(category.displayName(in: language))
                .font(Tokens.Typography.category.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Tokens.Palette.ink : Tokens.Palette.inkTertiary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                // A real 44 point target, which the old 31 point pill never was.
                .frame(minHeight: 44)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(isSelected ? Tokens.Palette.accent : .clear)
                        .frame(height: 2)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(category)
        .accessibilityIdentifier("feed.category.\(category.rawValue)")
        // Without this a reader using VoiceOver has no way to tell which category is showing.
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private var edgeFade: some View {
        LinearGradient(
            colors: [Tokens.Palette.background.opacity(0), Tokens.Palette.background],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 36)
        .allowsHitTesting(false)
    }
}
