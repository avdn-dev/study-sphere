import Foundation
import VISOR

@Observable
@ViewModel
final class ActiveSessionViewModel {

    enum Action {
        case startSession
        case endSession
        case leaveSession
        case leaveSessionGracefully
    }

    struct State: Equatable {
        @Bound(\ActiveSessionViewModel.sessionInteractor) var activeSession: StudySession?
        @Bound(\ActiveSessionViewModel.sessionInteractor) var participants: [Participant] = []
        @Bound(\ActiveSessionViewModel.sessionInteractor) var isHost = false
        @Bound(\ActiveSessionViewModel.sessionInteractor) var phase: StudySessionPhase = .idle
        @Bound(\ActiveSessionViewModel.sessionInteractor) var elapsedTime: TimeInterval?
        @Bound(\ActiveSessionViewModel.sessionInteractor) var isCalibrated = false
        @Bound(\ActiveSessionViewModel.distractionInteractor) var participantStatuses: [UUID: ParticipantStatus] = [:]
        @Bound(\ActiveSessionViewModel.distractionInteractor) var isLocalDeviceDistracted = false
        @Bound(\ActiveSessionViewModel.nearbyInteractionService) var estimatedPositions: [String: PeerPosition] = [:]
    }

    var state = State()

    var formattedElapsedTime: String? {
        guard let elapsed = state.elapsedTime else { return nil }
        let totalSeconds = Int(elapsed)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    func handle(_ action: Action) async {
        switch action {
        case .startSession:
            await sessionInteractor.startSession()
        case .endSession:
            await sessionInteractor.endSession()
        case .leaveSession:
            await sessionInteractor.leaveSession()
        case .leaveSessionGracefully:
            await sessionInteractor.leaveSessionGracefully()
        }
    }

    // MARK: - Private

    private let router: Router<AppScene>
    private let sessionInteractor: any SessionInteractor
    private let distractionInteractor: any DistractionInteractor
    private let nearbyInteractionService: any NearbyInteractionService
}
