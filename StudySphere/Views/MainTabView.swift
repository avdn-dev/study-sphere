import SwiftUI
import VISOR

@LazyViewModel(MainTabViewModel.self)
struct MainTabView: View {

    @Environment(Router<AppScene>.self) var router

    var content: some View {
        @Bindable var router = router

        return TabView(selection: $router.selectedTab) {
            NavigationContainer(parentRouter: router, tab: .focus) {
                FocusView()
            }
            .tabItem {
                Label("Focus", systemImage: "brain")
            }
            .tag(AppTab.focus)

            NavigationContainer(parentRouter: router, tab: .analytics) {
                SessionAnalyticsView()
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.bar.fill")
            }
            .tag(AppTab.analytics)
        }
    }
}
