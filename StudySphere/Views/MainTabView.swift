import SwiftUI
import VISOR

@LazyViewModel(MainTabViewModel.self)
struct MainTabView: View {

    @Environment(Router<AppScene>.self) var router

    var content: some View {
        @Bindable var router = router

        return TabView(selection: $router.selectedTab) {
            NavigationContainer(parentRouter: router, tab: .discover) {
                DiscoverView()
            }
            .tabItem {
                Label("Discover", systemImage: "magnifyingglass")
            }
            .tag(AppTab.discover)

            NavigationContainer(parentRouter: router, tab: .create) {
                CreateSessionView()
            }
            .tabItem {
                Label("Create", systemImage: "plus.circle.fill")
            }
            .tag(AppTab.create)

            NavigationContainer(parentRouter: router, tab: .profile) {
                ProfileView()
            }
            .tabItem {
                Label("Profile", systemImage: "person.circle")
            }
            .tag(AppTab.profile)
        }
    }
}
