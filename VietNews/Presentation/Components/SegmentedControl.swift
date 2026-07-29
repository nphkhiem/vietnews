import SwiftUI

/// A segmented picker built from tokens.
///
/// The stock control left a visible sliver of track at each end, because a `Form` row inset
/// compounds with `UISegmentedControl`'s own internal padding and neither can be reached from
/// SwiftUI. Drawing it ourselves means the segments meet the container's edges exactly.
struct SegmentedControl<Value: Hashable>: View {
    let options: [Value]
    let title: (Value) -> String
    /// Stable per-segment handle for UI tests. This is no longer a `UISegmentedControl`, so a
    /// test cannot reach the segments through the stock accessibility container.
    var identifier: ((Value) -> String)?
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let isSelected = option == selection

                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(Tokens.Typography.category.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Tokens.Palette.ink : Tokens.Palette.inkSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        // A neutral fill rather than the accent. Two large accent blocks on one
                        // screen leave nothing for the accent to actually signal.
                        .background(isSelected ? Tokens.Palette.hairline : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(identifier?(option) ?? "")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)

                if index < options.count - 1 {
                    Rectangle()
                        .fill(Tokens.Palette.hairline)
                        .frame(width: 1)
                        .accessibilityHidden(true)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.image))
        .overlay(
            RoundedRectangle(cornerRadius: Tokens.Radius.image)
                .stroke(Tokens.Palette.hairline, lineWidth: 1)
        )
    }
}

/// A labelled row that pushes to another screen.
struct SettingsLinkRow<Destination: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            HStack(spacing: Tokens.Space.m) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Tokens.Typography.category)
                        .foregroundStyle(Tokens.Palette.ink)
                    if let detail {
                        Text(detail)
                            .font(Tokens.Typography.summary)
                            .foregroundStyle(Tokens.Palette.inkTertiary)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(Tokens.Typography.summary.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, Tokens.Space.l)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A small uppercase heading above a group, matching the source marks used on the feed.
struct SettingsGroupLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(Tokens.Typography.meta)
            .tracking(0.8)
            .foregroundStyle(Tokens.Palette.inkTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Tokens.Space.l)
            .padding(.top, Tokens.Space.xl)
            .padding(.bottom, Tokens.Space.s)
            .accessibilityAddTraits(.isHeader)
    }
}
