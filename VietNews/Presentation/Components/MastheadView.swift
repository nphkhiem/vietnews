import SwiftUI

/// The app's own nameplate, replacing the stock inline navigation title.
///
/// The navigation title is why the top of the feed read as a generic application. A tracked
/// wordmark over a hairline is the first thing that says this is a paper.
///
/// Deliberately carries no search affordance yet. Search is ticket 33, and an icon that opens
/// nothing is worse than an icon that is not there.
struct MastheadView: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            // A step up from the metadata size the rest of the app uses for small tracked text.
            // The nameplate is the one place where being slightly louder is the point.
            .font(Tokens.Typography.masthead)
            .tracking(2.6)
            .foregroundStyle(Tokens.Palette.ink)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(Tokens.Palette.background)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Tokens.Palette.hairline)
                    .frame(height: 1)
            }
            .accessibilityAddTraits(.isHeader)
            // The nameplate is fixed furniture. Letting it grow with text pushes the news off
            // the screen to say something the reader already knows.
            .dynamicTypeSize(...DynamicTypeSize.large)
    }
}
