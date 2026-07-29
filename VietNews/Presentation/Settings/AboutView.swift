import SwiftUI

/// Version, and one thing the reader deserves to be told plainly.
struct AboutView: View {
    let language: Language

    var body: some View {
        VStack(alignment: .leading, spacing: Tokens.Space.l) {
            Text(L10n.aboutVersion(language, version))
                .font(Tokens.Typography.category)
                .foregroundStyle(Tokens.Palette.ink)

            // The README says the key is never committed, which is true of the repository and
            // easily misread as meaning it is secret at runtime. It is not: it ships inside the
            // app and anyone with a copy can read it.
            Text(L10n.aboutAPIKeyNotice(language))
                .font(Tokens.Typography.summary)
                .foregroundStyle(Tokens.Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(Tokens.Space.l)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Tokens.Palette.background)
        .navigationTitle(L10n.settingsSectionAbout(language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var version: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(short) (\(build))"
    }
}
