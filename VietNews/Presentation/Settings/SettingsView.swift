import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var feedViewModel: NewsFeedViewModel
    @State private var isAddingFeed = false

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
                .padding(.bottom, Tokens.Space.xxxl)
            }
            .background(Tokens.Palette.background)
            .navigationTitle(L10n.settingsTitle(language))
        }
        .sheet(isPresented: $isAddingFeed) {
            FeedSubscriptionSheet(
                viewModel: viewModel.makeSubscriptionViewModel(),
                language: language,
                onFinished: { isAddingFeed = false }
            )
        }
    }

    /// Reading comes first, and language first within it, because it is the preference that
    /// changes everything else on the screen.
    private var reading: some View {
        SettingsGroup(title: L10n.settingsSectionReading(language)) {
            SettingsField(title: L10n.settingsSectionLanguage(language)) {
                SegmentedControl(
                    options: Language.allCases,
                    // Deliberately untranslated. A language is always listed in its own name, so
                    // a reader who cannot read the current one can still find theirs.
                    title: { $0 == .vietnamese ? "Tiếng Việt" : "English" },
                    identifier: { "settings.language.\($0.rawValue)" },
                    selection: languageBinding
                )
            }

            SettingsField(title: L10n.settingsSectionMaxArticles(language)) {
                SegmentedControl(
                    options: SettingsViewModel.articleCountOptions,
                    title: { "\($0)" },
                    selection: $viewModel.maxArticles
                )
            }
        }
    }

    private var refresh: some View {
        SettingsGroup(title: L10n.settingsSectionAutoRefresh(language)) {
            // Same rhythm as a `SettingsField`, but the interval is the slider's live readout
            // rather than a static label, so it keeps the primary reading colour.
            VStack(alignment: .leading, spacing: Tokens.Space.s) {
                Text(intervalLabel)
                    .font(Tokens.Typography.category)
                    .foregroundStyle(Tokens.Palette.ink)
                Slider(value: $viewModel.refreshInterval, in: 300...600, step: 60)
                    .tint(Tokens.Palette.accent)
            }
            .padding(.horizontal, Tokens.Space.l)
        }
    }

    private var subscriptions: some View {
        SettingsGroup(title: L10n.settingsSectionSubstack(language)) {
            // A list reads as one block, so its rows sit flush and are separated by rule rather
            // than by the gap the group uses between fields.
            VStack(spacing: 0) {
                ForEach(viewModel.substackFeeds, id: \.url) { feed in
                    SettingsLabelledRow(
                        title: feed.url.host ?? feed.url.absoluteString,
                        detail: feed.category.displayName(in: language)
                    )
                    Divider().overlay(Tokens.Palette.hairline)
                }

                // Adding is a task with a beginning and an end, so it opens a sheet rather than
                // living as three loose controls with the confirm button below the fold.
                Button { isAddingFeed = true } label: {
                    SettingsLabelledRow(
                        title: L10n.sourcesAdd(language),
                        detail: L10n.sourcesAddDetail(language),
                        showsChevron: true
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.addFeed")
            }
        }
    }

    /// Sources, storage and about are each their own screen.
    private var more: some View {
        SettingsGroup(title: L10n.settingsSectionAbout(language)) {
            VStack(spacing: 0) {
                SettingsLinkRow(title: L10n.sourcesTitle(language), identifier: "settings.sources") {
                    SourcesView(
                        language: language,
                        makeSubscriptionViewModel: { viewModel.makeSubscriptionViewModel() },
                        makeViewModel: { viewModel.makeSourcesViewModel(language: language) }
                    )
                }
                Divider().overlay(Tokens.Palette.hairline)
                SettingsLinkRow(title: L10n.settingsSectionStorage(language)) {
                    StorageView(language: language, cacheRepository: viewModel.cacheRepository)
                }
                Divider().overlay(Tokens.Palette.hairline)
                SettingsLinkRow(title: L10n.settingsSectionAbout(language)) {
                    AboutView(language: language)
                }
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
