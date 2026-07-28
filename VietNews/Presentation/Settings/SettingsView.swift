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
            Form {
                Section(L10n.settingsSectionLanguage(language)) {
                    Picker(L10n.settingsSectionLanguage(language), selection: languageBinding) {
                        // Deliberately not translated. A language is always listed in its own
                        // name, so a reader who cannot read the current language can still find
                        // the one they want.
                        Text("Tiếng Việt").tag(Language.vietnamese)
                        Text("English").tag(Language.english)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("settings.language.picker")
                }

                Section(L10n.settingsSectionAutoRefresh(language)) {
                    VStack(alignment: .leading) {
                        Text(intervalLabel)
                        Slider(value: $viewModel.refreshInterval, in: 300...600, step: 60)
                    }
                }

                Section(L10n.settingsSectionMaxArticles(language)) {
                    Picker(
                        L10n.settingsMaxArticlesLabel(language),
                        selection: $viewModel.maxArticles
                    ) {
                        ForEach([15, 30, 50, 70], id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section(L10n.settingsSectionSubstack(language)) {
                    ForEach(viewModel.substackFeeds, id: \.url) { feed in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.url.host ?? feed.url.absoluteString)
                            Text(feed.category.displayName(in: language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.removeSubstackFeed(at: offsets)
                    }

                    TextField(
                        L10n.settingsSubstackURLPlaceholder(language),
                        text: $newFeedURL
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    Picker(L10n.settingsCategory(language), selection: $newFeedCategory) {
                        Text(NewsCategory.work.displayName(in: language))
                            .tag(NewsCategory.work)
                        Text(NewsCategory.technology.displayName(in: language))
                            .tag(NewsCategory.technology)
                    }

                    Button(L10n.settingsAdd(language)) {
                        if viewModel.addSubstackFeed(urlString: newFeedURL, category: newFeedCategory) {
                            newFeedURL = ""
                        } else {
                            showInvalidURLAlert = true
                        }
                    }
                    .disabled(newFeedURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle(L10n.settingsTitle(language))
            .alert(
                L10n.settingsInvalidURLTitle(language),
                isPresented: $showInvalidURLAlert
            ) {
                // "OK" is used as-is in both languages.
                Button("OK", role: .cancel) {}
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
