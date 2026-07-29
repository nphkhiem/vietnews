import Factory
import SwiftUI

struct RootView: View {
    @StateObject private var networkMonitor = Container.shared.networkMonitor()
    @StateObject private var feedViewModel = Container.shared.newsFeedViewModel()

    var body: some View {
        TabView {
            NewsFeedView(viewModel: feedViewModel)
                .tabItem {
                    Label(L10n.tabFeed(feedViewModel.language), systemImage: "newspaper")
                }

            SettingsView(
                viewModel: Container.shared.settingsViewModel(),
                feedViewModel: feedViewModel
            )
            .tabItem {
                Label(L10n.tabSettings(feedViewModel.language), systemImage: "gearshape")
            }
        }
        // The last system blue on screen. Without this the strip and the tab bar disagree about
        // what the app's accent colour is.
        .tint(Tokens.Palette.accent)
        .safeAreaInset(edge: .top, spacing: 0) {
            if !networkMonitor.isOnline {
                Text(L10n.bannerOffline(feedViewModel.language))
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.9))
                    .foregroundStyle(.white)
            }
        }
    }
}
