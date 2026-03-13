import Foundation
import VISOR

@Observable
@ViewModel
final class AppSelectionViewModel {

    enum Action {
        case done
    }

    struct State: Equatable {
        @Bound(\AppSelectionViewModel.screenTimeService) var isAuthorized = false
    }

    var state = State()

    func handle(_ action: Action) async {
        switch action {
        case .done:
            router.dismissSheet()
        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    private let screenTimeService: any ScreenTimeService
}
