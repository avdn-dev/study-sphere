import Foundation
import VISOR

@Observable
@ViewModel
final class CreateSessionViewModel {

    enum Action {
        case updateSessionName(String)
        case updateRadius(Double)
        case updateDuration(TimeInterval)
        case toggleStillness(Bool)
        case showAppSelection
        case requestScreenTimeAuth
        case createSession
    }

    struct State: Equatable {
        @Bound(\CreateSessionViewModel.sessionInteractor) var isScreenTimeAuthorized = false
        var sessionName = ""
        var radiusMeters: Double = 5.0
        var durationSeconds: TimeInterval = 1800
        var requireStillness = false
        var isCreating = false
    }

    var state = State()

    func handle(_ action: Action) async {
        switch action {
        case .updateSessionName(let name):
            state.sessionName = name
        case .updateRadius(let radius):
            state.radiusMeters = radius
        case .updateDuration(let duration):
            state.durationSeconds = duration
        case .toggleStillness(let value):
            state.requireStillness = value
        case .showAppSelection:
            router.present(sheet: .appSelection)
        case .requestScreenTimeAuth:
            try? await sessionInteractor.requestScreenTimeAuthorization()
        case .createSession:
            state.isCreating = true
            let settings = SessionSettings(
                sessionName: state.sessionName,
                radiusMeters: state.radiusMeters,
                durationSeconds: state.durationSeconds,
                requireStillness: state.requireStillness)
            await sessionInteractor.createSession(settings: settings)
            state.isCreating = false
            router.dismissSheet()
            router.present(fullScreen: .activeSession)
        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    private let sessionInteractor: any SessionInteractor
}
