import Foundation
import VISOR

@Observable
@ViewModel
final class MainTabViewModel {

    typealias Action = Never

    struct State: Equatable {}

    var state = State()

    @Reaction(\MainTabViewModel.router.selectedTab)
    func handleTabChange(tab: AppTab?) {
        guard let tab else { return }
        if let previousTab {
            router.childRouter(for: previousTab).popToRoot()
        }
        previousTab = tab
    }

    // MARK: - Private

    private var previousTab: AppTab?
    private let router: Router<AppScene>
}
