import Foundation
import VISOR

@Observable
@ViewModel
final class CreateSessionViewModel {

    enum Action {
        case updateSessionName(String)
        case updateRadius(Double)
        case toggleStillness(Bool)
        case updateAlertSound(AlertSound)
        case previewAlertSound(AlertSound)
        case showAppSelection
        case requestScreenTimeAuth
        case createSession
    }

    struct State: Equatable {
        @Bound(\CreateSessionViewModel.sessionInteractor) var isScreenTimeAuthorized = false
        var sessionName = ""
        var radiusMeters: Double = 5.0
        var requireStillness = false
        var alertSound: AlertSound = .carAlarm
        var isCreating = false
    }

    var state = State()

    func handle(_ action: Action) async {
        switch action {
        case .updateSessionName(let name):
            state.sessionName = name
        case .updateRadius(let radius):
            state.radiusMeters = radius
        case .toggleStillness(let value):
            state.requireStillness = value
        case .updateAlertSound(let sound):
            state.alertSound = sound
        case .previewAlertSound(let sound):
            if let url = sound.url {
                try? audioService.play(url: url, volume: 1.0)
            }
        case .showAppSelection:
            router.present(sheet: .appSelection)
        case .requestScreenTimeAuth:
            try? await sessionInteractor.requestScreenTimeAuthorization()
        case .createSession:
            state.isCreating = true
            let settings = SessionSettings(
                sessionName: state.sessionName,
                radiusMeters: state.radiusMeters,
                requireStillness: state.requireStillness,
                alertSound: state.alertSound)
            await sessionInteractor.createSession(settings: settings)
            state.isCreating = false
            router.dismissSheet()
            router.present(fullScreen: .activeSession)
        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    private let sessionInteractor: any SessionInteractor
    private let audioService: any AudioService
}
