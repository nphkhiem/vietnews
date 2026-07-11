import SwiftUI

struct CategoryTabBar: View {
    let categories: [NewsCategory]
    let selected: NewsCategory
    let language: Language
    let onSelect: (NewsCategory) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(categories, id: \.self) { category in
                        Button {
                            onSelect(category)
                        } label: {
                            Text(category.displayName(in: language))
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(
                                    Capsule().fill(
                                        category == selected
                                            ? Color.accentColor
                                            : Color(.secondarySystemBackground)
                                    )
                                )
                                .foregroundStyle(category == selected ? .white : .primary)
                        }
                        .id(category)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .onChange(of: selected) { newValue in
                withAnimation { proxy.scrollTo(newValue, anchor: .center) }
            }
        }
    }
}
