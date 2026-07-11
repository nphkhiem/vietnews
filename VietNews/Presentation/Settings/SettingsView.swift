import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @ObservedObject var feedViewModel: NewsFeedViewModel
    @State private var newFeedURL = ""
    @State private var newFeedCategory: NewsCategory = .technology
    @State private var showInvalidURLAlert = false

    private var isVietnamese: Bool { feedViewModel.language == .vietnamese }

    var body: some View {
        NavigationStack {
            Form {
                Section(isVietnamese ? "Ngôn ngữ" : "Language") {
                    Picker(isVietnamese ? "Ngôn ngữ" : "Language", selection: languageBinding) {
                        Text("Tiếng Việt").tag(Language.vietnamese)
                        Text("English").tag(Language.english)
                    }
                    .pickerStyle(.segmented)
                }

                Section(isVietnamese ? "Tự động làm mới" : "Auto-refresh") {
                    VStack(alignment: .leading) {
                        Text(intervalLabel)
                        Slider(value: $viewModel.refreshInterval, in: 300...600, step: 60)
                    }
                }

                Section(isVietnamese ? "Substack đã theo dõi" : "Substack subscriptions") {
                    ForEach(viewModel.substackFeeds, id: \.url) { feed in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(feed.url.host ?? feed.url.absoluteString)
                            Text(feed.category.displayName(in: feedViewModel.language))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { offsets in
                        viewModel.removeSubstackFeed(at: offsets)
                    }

                    TextField(
                        isVietnamese ? "Địa chỉ Substack" : "Substack URL",
                        text: $newFeedURL
                    )
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)

                    Picker(isVietnamese ? "Chuyên mục" : "Category", selection: $newFeedCategory) {
                        Text(NewsCategory.work.displayName(in: feedViewModel.language))
                            .tag(NewsCategory.work)
                        Text(NewsCategory.technology.displayName(in: feedViewModel.language))
                            .tag(NewsCategory.technology)
                    }

                    Button(isVietnamese ? "Thêm" : "Add") {
                        if viewModel.addSubstackFeed(urlString: newFeedURL, category: newFeedCategory) {
                            newFeedURL = ""
                        } else {
                            showInvalidURLAlert = true
                        }
                    }
                    .disabled(newFeedURL.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle(isVietnamese ? "Cài đặt" : "Settings")
            .alert(
                isVietnamese ? "Địa chỉ không hợp lệ" : "Invalid URL",
                isPresented: $showInvalidURLAlert
            ) {
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
        let minutes = Int(viewModel.refreshInterval / 60)
        return isVietnamese ? "Mỗi \(minutes) phút" : "Every \(minutes) minutes"
    }
}
