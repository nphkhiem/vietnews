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

/// A title with an optional supporting line beneath, at the one row height this screen uses.
/// Every list row on the settings screen is this, so the rows keep the same rhythm whether or
/// not they lead anywhere.
struct SettingsLabelledRow: View {
    let title: String
    var detail: String?
    var showsChevron = false

    var body: some View {
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
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(Tokens.Typography.summary.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.inkTertiary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }
}

/// A labelled row that pushes to another screen.
struct SettingsLinkRow<Destination: View>: View {
    let title: String
    var detail: String?
    @ViewBuilder let destination: () -> Destination

    var body: some View {
        NavigationLink(destination: destination) {
            SettingsLabelledRow(title: title, detail: detail, showsChevron: true)
        }
        .buttonStyle(.plain)
    }
}

/// A group of settings under a small uppercase heading, matching the source marks on the feed.
///
/// This owns every vertical gap on the settings screen: `Space.l` between the heading and the
/// fields and between one field and the next, `Space.xxxl` between one group and the next. When
/// the individual views each carried a slice of their own spacing instead, the gaps disagreed
/// from group to group and one heading ended up indented further than the rest.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text(title.uppercased())
                .font(Tokens.Typography.meta)
                .tracking(0.8)
                .foregroundStyle(Tokens.Palette.inkTertiary)
                .padding(.horizontal, Tokens.Space.l)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Tokens.Space.xxxl)
    }
}

/// A label above the control it describes, held closer to it than groups are held to each other
/// so the pairing is read from the spacing alone.
struct SettingsField<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.s) {
            Text(title)
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
            content()
        }
        .padding(.horizontal, Tokens.Space.l)
    }
}
