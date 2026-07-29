import SwiftUI

/// A placeholder in the shape of an article row.
///
/// Hidden from assistive technology outright. Read aloud, eight of these announced themselves as
/// a list of empty items, which tells a reader the feed arrived and is blank rather than that it
/// is still loading.
///
/// Drawn from tokens rather than from `secondarySystemBackground`, which was the last piece of
/// the feed still taking its colour from the system rather than from the palette.
struct SkeletonRowView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        HStack(alignment: .top, spacing: Tokens.Space.m) {
            block(
                width: Tokens.Layout.thumbnailSide,
                height: Tokens.Layout.thumbnailSide,
                radius: Tokens.Radius.image
            )

            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                block(height: 14)
                block(width: 180, height: 14)
                block(width: 100, height: 10)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        // A pulse that never stops is exactly what Reduce Motion asks an app not to do. The
        // placeholder still reads as one without it, because its shape already says so.
        .opacity(pulsing ? 0.4 : 1.0)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: pulsing
        )
        .onAppear { pulsing = !reduceMotion }
        .accessibilityHidden(true)
    }

    private func block(width: CGFloat? = nil, height: CGFloat, radius: CGFloat = 2) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Tokens.Palette.hairline)
            .frame(width: width, height: height)
            .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
}
