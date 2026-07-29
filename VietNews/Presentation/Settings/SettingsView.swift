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
                .padding(.bottom, Tokens.Space.xxxl)
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
            }

            // The add form needs no label of its own: the placeholder already says what the
            // field is, and the group heading says what it adds to.
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
                .frame(maxWidth: .infinity, minHeight: 44)
                .overlay(
                    RoundedRectangle(cornerRadius: Tokens.Radius.image)
                        .stroke(Tokens.Palette.hairline, lineWidth: 1)
                )
                .disabled(newFeedURL.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, Tokens.Space.l)
        }
    }

    /// Sources, storage and about are each their own screen.
    private var more: some View {
        SettingsGroup(title: L10n.settingsSectionAbout(language)) {
            VStack(spacing: 0) {
                SettingsLinkRow(title: L10n.sourcesTitle(language), identifier: "settings.sources") {
                    SourcesView(language: language) { viewModel.makeSourcesViewModel(language: language) }
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
