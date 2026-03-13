import Foundation
import VISOR

@Observable
@ViewModel
final class ActiveSessionViewModel {

    enum Action {
        case startSession
        case endSession
        case leaveSession
    }

    struct State: Equatable {
        @Bound(\ActiveSessionViewModel.sessionInteractor) var activeSession: StudySession?
        @Bound(\ActiveSessionViewModel.sessionInteractor) var participants: [Participant] = []
        @Bound(\ActiveSessionViewModel.sessionInteractor) var isHost = false
        @Bound(\ActiveSessionViewModel.sessionInteractor) var remainingTime: TimeInterval?
        @Bound(\ActiveSessionViewModel.sessionInteractor) var isCalibrated = false
        @Bound(\ActiveSessionViewModel.distractionInteractor) var participantStatuses: [UUID: ParticipantStatus] = [:]
        @Bound(\ActiveSessionViewModel.distractionInteractor) var isLocalDeviceDistracted = false
        @Bound(\ActiveSessionViewModel.nearbyInteractionService) var estimatedPositions: [String: PeerPosition] = [:]
    }

    var state = State()

    var formattedRemainingTime: String? {
        guard let remaining = state.remainingTime else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    func handle(_ action: Action) async {
        switch action {
        case .startSession:
            await sessionInteractor.startSession()
        case .endSession:
            await sessionInteractor.endSession()
            router.dismissFullScreen()
        case .leaveSession:
            await sessionInteractor.leaveSession()
            router.dismissFullScreen()
        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    private let sessionInteractor: SessionInteractor
    private let distractionInteractor: DistractionInteractor
    private let nearbyInteractionService: NearbyInteractionService
}
