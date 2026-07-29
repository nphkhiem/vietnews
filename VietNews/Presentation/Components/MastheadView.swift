import SwiftUI

/// The app's own nameplate, and the only kind of screen title in the app.
///
/// The stock navigation title is why the top of a screen read as a generic application. A tracked
/// wordmark over a hairline is the first thing that says this is a paper.
///
/// Every screen uses it, not just the feed. Settings, Sources, Search, Storage and About each had
/// a stock navigation title, so the app carried two different kinds of heading: a tracked wordmark
/// on two screens and the system font on the rest.
///
/// The leading and trailing slots are symmetric and optional, which is what lets one component
/// serve a root screen with a search icon, a pushed screen with a back chevron, and a sheet with a
/// cancel button.
struct MastheadView: View {
    /// A control in one of the masthead's edge slots.
    struct Action {
        let label: String
        /// An SF Symbol, or nil to render the label as text. A back chevron is a symbol; a sheet's
        /// cancel is a word.
        var systemImage: String?
        var identifier: String?
        let perform: () -> Void
    }

    let title: String
    var leading: Action?
    var trailing: Action?

    var body: some View {
        ZStack {
            Text(title.uppercased())
                // A step up from the metadata size the rest of the app uses for small tracked
                // text. The nameplate is the one place where being slightly louder is the point.
                .font(Tokens.Typography.masthead)
                .tracking(2.6)
                .foregroundStyle(Tokens.Palette.ink)
                .lineLimit(1)
                // Never let an edge control push the wordmark off centre; it yields first.
                .padding(.horizontal, 56)
                .accessibilityAddTraits(.isHeader)

            // Overlaid rather than placed in a row, so the wordmark stays centred on the screen
            // rather than centred on whatever space is left beside the controls.
            HStack(spacing: 0) {
                if let leading {
                    control(leading, alignment: .leading)
                }
                Spacer(minLength: 0)
                if let trailing {
                    control(trailing, alignment: .trailing)
                }
            }
            .padding(.horizontal, Tokens.Space.s)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(Tokens.Palette.background)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Tokens.Palette.hairline)
                .frame(height: 1)
        }
        // The nameplate is fixed furniture. Letting it grow with text pushes the news off the
        // screen to say something the reader already knows.
        .dynamicTypeSize(...DynamicTypeSize.large)
    }

    private func control(_ action: Action, alignment: HorizontalAlignment) -> some View {
        Button(action: action.perform) {
            Group {
                if let systemImage = action.systemImage {
                    Image(systemName: systemImage)
                        .font(Tokens.Typography.category.weight(.semibold))
                } else {
                    Text(action.label)
                        .font(Tokens.Typography.category)
                        .lineLimit(1)
                }
            }
            .foregroundStyle(Tokens.Palette.ink)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(action.label)
        .accessibilityIdentifier(action.identifier ?? "")
    }
}

extension MastheadView.Action {
    /// The way back from a pushed screen, now that the navigation bar carrying it is hidden.
    static func back(label: String, perform: @escaping () -> Void) -> Self {
        .init(label: label, systemImage: "chevron.left", identifier: "masthead.back", perform: perform)
    }

    static func search(label: String, perform: @escaping () -> Void) -> Self {
        .init(label: label, systemImage: "magnifyingglass", identifier: "masthead.search", perform: perform)
    }
}
