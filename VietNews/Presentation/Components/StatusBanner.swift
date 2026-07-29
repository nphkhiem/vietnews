import SwiftUI

/// One component for everything the feed needs to tell the reader about its own state.
///
/// This replaces three separate ad hoc views that had drifted into three different vocabularies,
/// including an offline strip in white on orange that measured about two to one and failed the
/// contrast requirement outright.
struct StatusBanner: View {
    enum Severity {
        /// Worth knowing, nothing to do about it. Being offline, or reading older news.
        case caution
        /// Something is broken and the reader may want to act.
        case problem

        var rule: Color {
            switch self {
            case .caution: return Tokens.Palette.caution
            case .problem: return Tokens.Palette.accent
            }
        }
    }

    let severity: Severity
    let message: String
    var detail: String?
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(spacing: Tokens.Space.m) {
            // Severity is carried by the rule, but never only by the rule: the wording differs
            // too, so it survives being read aloud or seen without colour.
            RoundedRectangle(cornerRadius: 1)
                .fill(severity.rule)
                .frame(width: 3)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(message)
                    .font(Tokens.Typography.summary)
                    .foregroundStyle(Tokens.Palette.ink)
                if let detail {
                    Text(detail)
                        .font(Tokens.Typography.summary)
                        .foregroundStyle(Tokens.Palette.inkSecondary)
                }
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(Tokens.Typography.summary.weight(.semibold))
                    .foregroundStyle(Tokens.Palette.accent)
                    .frame(minHeight: 44)
            }
        }
        .padding(.horizontal, Tokens.Space.l)
        .padding(.vertical, Tokens.Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Palette.background)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Tokens.Palette.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
