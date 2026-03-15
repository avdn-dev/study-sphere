import Foundation
import FamilyControls
import VISOR

@Observable
@ViewModel
final class AppSelectionViewModel {

    enum Action {
        case done
        case openBlockedAppsPicker
    }

    struct State: Equatable {
        @Bound(\ScreenTimeViewModel.screenTimeService) var blockedApps: FamilyActivitySelection = .init()
        @Bound(\AppSelectionViewModel.permissionsService) var isScreenTimeAuthorized: Bool = false
        var isBlockedAppPickerPresented = false
    }

    var state = State()

    func handle(_ action: Action) async {
        switch action {
        case .openBlockedAppsPicker:
          do {
            try await permissionsService.requestScreenTimesPermission()
            updateState(\.isBlockedAppPickerPresented, to: true)
          } catch {
            fatalError("Failed to request screen time permission: \(error)")
          }
        case .done:
            router.dismissSheet()
        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    let screenTimeService: any ScreenTimeService
    let permissionsService: any PermissionsService
}
