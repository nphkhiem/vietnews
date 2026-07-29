import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var feedViewModel: NewsFeedViewModel
    @State private var newFeedURL = ""
    @State private var newFeedCategory: NewsCategory = .technology
    @State private var showInvalidURLAlert = false

    private var language: Language { feedViewModel.language }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    reading
                    refresh
                    subscriptions
                    more
                }
                .padding(.bottom, Tokens.Space.xxl)
            }
            .background(Tokens.Palette.background)
            .navigationTitle(L10n.settingsTitle(language))
            .alert(L10n.settingsInvalidURLTitle(language), isPresented: $showInvalidURLAlert) {
                // "OK" is used as-is in both languages.
                Button("OK", role: .cancel) {}
            }
        }
    }

    /// Reading comes first, and language first within it, because it is the preference that
    /// changes everything else on the screen.
    private var reading: some View {
        VStack(spacing: Tokens.Space.m) {
            SettingsGroupLabel(title: L10n.settingsSectionReading(language))

            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text(L10n.settingsSectionLanguage(language))
                    .font(Tokens.Typography.summary)
                    .foregroundStyle(Tokens.Palette.inkSecondary)
                SegmentedControl(
                    options: Language.allCases,
                    // Deliberately untranslated. A language is always listed in its own name, so
                    // a reader who cannot read the current one can still find theirs.
                    title: { $0 == .vietnamese ? "Tiếng Việt" : "English" },
                    identifier: { "settings.language.\($0.rawValue)" },
                    selection: languageBinding
                )
            }
            .padding(.horizontal, Tokens.Space.l)

            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text(L10n.settingsSectionMaxArticles(language))
                    .font(Tokens.Typography.summary)
                    .foregroundStyle(Tokens.Palette.inkSecondary)
                SegmentedControl(
                    options: SettingsViewModel.articleCountOptions,
                    title: { "\($0)" },
                    selection: $viewModel.maxArticles
                )
            }
            .padding(.horizontal, Tokens.Space.l)
        }
    }

    private var refresh: some View {
        // The group label applies its own horizontal padding, so it sits outside this stack's.
        // Nesting it inside doubled the inset and left this one heading further in than the rest.
        VStack(alignment: .leading, spacing: 0) {
            SettingsGroupLabel(title: L10n.settingsSectionAutoRefresh(language))

            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text(intervalLabel)
                    .font(Tokens.Typography.category)
                    .foregroundStyle(Tokens.Palette.ink)
                Slider(value: $viewModel.refreshInterval, in: 300...600, step: 60)
                    .tint(Tokens.Palette.accent)
            }
            .padding(.horizontal, Tokens.Space.l)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var subscriptions: some View {
        VStack(spacing: 0) {
            SettingsGroupLabel(title: L10n.settingsSectionSubstack(language))

            ForEach(viewModel.substackFeeds, id: \.url) { feed in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feed.url.host ?? feed.url.absoluteString)
                            .font(Tokens.Typography.category)
                            .foregroundStyle(Tokens.Palette.ink)
                        Text(feed.category.displayName(in: language))
                            .font(Tokens.Typography.summary)
                            .foregroundStyle(Tokens.Palette.inkTertiary)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Tokens.Space.l)
                .frame(minHeight: 52)
            }

            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                TextField(L10n.settingsSubstackURLPlaceholder(language), text: $newFeedURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(Tokens.Typography.category)
                    .padding(Tokens.Space.m)
                    .background(Tokens.Palette.surface)
                    .clipShape(RoundedRectangle(cornerRadius: Tokens.Radius.image))

                SegmentedControl(
                    options: [NewsCategory.work, .technology],
                    title: { $0.displayName(in: language) },
                    selection: $newFeedCategory
                )

                Button(L10n.settingsAdd(language)) {
                    if viewModel.addSubstackFeed(urlString: newFeedURL, category: newFeedCategory) {
                        newFeedURL = ""
                    } else {
                        showInvalidURLAlert = true
                    }
                }
                .font(Tokens.Typography.category.weight(.semibold))
                .foregroundStyle(newFeedURL.trimmingCharacters(in: .whitespaces).isEmpty
                    ? Tokens.Palette.inkTertiary
                    : Tokens.Palette.accent)
                .frame(minHeight: 44)
                .disabled(newFeedURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Tokens.Space.l)
        }
    }

    /// Storage and About are their own screens. Sources belongs here too and is deliberately
    /// absent until ticket 29 builds the screen behind it, on the same reasoning that kept the
    /// search affordance out of the masthead.
    private var more: some View {
        VStack(spacing: 0) {
            SettingsGroupLabel(title: L10n.settingsSectionAbout(language))

            SettingsLinkRow(title: L10n.settingsSectionStorage(language)) {
                StorageView(language: language, cacheRepository: viewModel.cacheRepository)
            }
            Divider().overlay(Tokens.Palette.hairline)
            SettingsLinkRow(title: L10n.settingsSectionAbout(language)) {
                AboutView(language: language)
            }
        }
    }

    private var languageBinding: Binding<Language> {
        Binding(
            get: { feedViewModel.language },
            set: { newValue in Task { await feedViewModel.setLanguage(newValue) } }
        )
    }

    private var intervalLabel: String {
        L10nPlural.settingsInterval(language, count: Int(viewModel.refreshInterval / 60))
    }
}
