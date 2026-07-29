import SwiftUI

/// Version, and one thing the reader deserves to be told plainly.
struct AboutView: View {
    let language: Language
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            MastheadView(
                title: L10n.settingsSectionAbout(language),
                leading: .back(label: L10n.commonBack(language)) { dismiss() }
            )

            VStack(alignment: .leading, spacing: Tokens.Space.l) {
                Text(L10n.aboutVersion(language, version))
                    .font(Tokens.Typography.category)
                    .foregroundStyle(Tokens.Palette.ink)

                // Said in the app as well as in the README, because the person holding a build is
                // not necessarily the person who read the repository. The key ships inside the app
                // and anyone with a copy can read it.
                Text(L10n.aboutAPIKeyNotice(language))
                    .font(Tokens.Typography.summary)
                    .foregroundStyle(Tokens.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding(Tokens.Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Tokens.Palette.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
