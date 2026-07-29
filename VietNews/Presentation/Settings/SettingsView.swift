import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var feedViewModel: NewsFeedViewModel
    @State private var isAddingFeed = false

    private var language: Language { feedViewModel.language }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                MastheadView(title: L10n.settingsTitle(language))
                ScrollView {
                    VStack(spacing: 0) {
                        languageSetting
                        maxArticles
                        refresh
                        subscriptions
                        more
                    }
                    .padding(.bottom, Tokens.Space.xxxl)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Tokens.Palette.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $isAddingFeed) {
            FeedSubscriptionSheet(
                viewModel: viewModel.makeSubscriptionViewModel(),
                language: language,
                onFinished: { isAddingFeed = false }
            )
        }
    }

    /// Language comes first because it is the preference that changes everything else on the
    /// screen.
    ///
    /// Its own group rather than a labelled field inside a "Reading" one. The screen used to
    /// carry two kinds of label: uppercase tracked headings for groups, and sentence case labels
    /// for the fields under them, which read as two competing title styles on one screen. Every
    /// section is a heading and its control now.
    private var languageSetting: some View {
        SettingsGroup(title: L10n.settingsSectionLanguage(language)) {
            SegmentedControl(
                options: Language.allCases,
                // Deliberately untranslated. A language is always listed in its own name, so
                // a reader who cannot read the current one can still find theirs.
                title: { $0 == .vietnamese ? "Tiếng Việt" : "English" },
                identifier: { "settings.language.\($0.rawValue)" },
                selection: languageBinding
            )
            .padding(.horizontal, Tokens.Space.l)
        }
    }

    private var maxArticles: some View {
        SettingsGroup(title: L10n.settingsSectionMaxArticles(language)) {
            SegmentedControl(
                options: SettingsViewModel.articleCountOptions,
                title: { "\($0)" },
                selection: $viewModel.maxArticles
            )
            .padding(.horizontal, Tokens.Space.l)
        }
    }

    private var refresh: some View {
        SettingsGroup(title: L10n.settingsSectionAutoRefresh(language)) {
            SegmentedControl(
                options: SettingsViewModel.refreshIntervalOptions,
                title: { Self.intervalLabel(for: $0, language: language) },
                identifier: { "settings.refresh.\(Int($0))" },
                selection: $viewModel.refreshInterval
            )
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

    /// Off reads as a word rather than as a zero, because a segment saying "0 minutes" would be
    /// describing a refresh that happens constantly rather than one that never happens.
    ///
    /// Just the duration, not "Every 5 minutes". Five segments of a full sentence truncated to
    /// "Mỗi 5 p…" and said nothing at all.
    private static func intervalLabel(for interval: TimeInterval, language: Language) -> String {
        guard interval > 0 else { return L10n.settingsRefreshOff(language) }
        return L10nPlural.settingsRefreshMinutes(language, count: Int(interval / 60))
    }
}
