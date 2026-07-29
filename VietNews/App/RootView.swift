import Factory
import SwiftUI

struct RootView: View {
    @StateObject private var networkMonitor = Container.shared.networkMonitor()
    @StateObject private var feedViewModel = Container.shared.newsFeedViewModel()

    var body: some View {
        TabView {
            NewsFeedView(viewModel: feedViewModel, isOffline: !networkMonitor.isOnline)
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
    }
}
