import SwiftUI

/// Shown when a category has nothing in it, and when a load failed.
///
/// Both were dead ends before: the empty state offered nothing at all, and neither could be
/// pulled to refresh. A reader who arrives at either now has something to do.
struct EmptyStateView: View {
    let systemImage: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: Tokens.Space.m) {
            Image(systemName: systemImage)
                .font(.largeTitle)
                .foregroundStyle(Tokens.Palette.inkTertiary)
                // Decoration. The message says the same thing in words.
                .accessibilityHidden(true)

            Text(message)
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button(actionTitle, action: action)
                .font(Tokens.Typography.category.weight(.semibold))
                .foregroundStyle(Tokens.Palette.onAccent)
                .padding(.horizontal, Tokens.Space.xl)
                .padding(.vertical, Tokens.Space.m)
                .background(Capsule().fill(Tokens.Palette.accent))
                .frame(minHeight: 44)
        }
        .padding(Tokens.Space.xxl)
        .frame(maxWidth: .infinity)
    }
}
