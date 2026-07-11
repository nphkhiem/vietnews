import Factory
import SwiftUI

struct RootView: View {
    @StateObject private var networkMonitor = Container.shared.networkMonitor()
    @StateObject private var feedViewModel = Container.shared.newsFeedViewModel()

    var body: some View {
        TabView {
            NewsFeedView(viewModel: feedViewModel)
                .tabItem {
                    Label(
                        feedViewModel.language == .vietnamese ? "Tin tức" : "Feed",
                        systemImage: "newspaper"
                    )
                }

            SettingsView(
                viewModel: Container.shared.settingsViewModel(),
                feedViewModel: feedViewModel
            )
            .tabItem {
                Label(
                    feedViewModel.language == .vietnamese ? "Cài đặt" : "Settings",
                    systemImage: "gearshape"
                )
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !networkMonitor.isOnline {
                Text(feedViewModel.language == .vietnamese
                     ? "Ngoại tuyến — đang hiển thị tin đã lưu"
                     : "Offline — showing cached news")
                    .font(.caption.weight(.medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.9))
                    .foregroundStyle(.white)
            }
        }
    }
}
