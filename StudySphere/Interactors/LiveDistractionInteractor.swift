import Foundation
import VISOR

@Observable
final class LiveDistractionInteractor: DistractionInteractor {

    init(
        motionService: MotionService,
        screenTimeService: ScreenTimeService,
        nearbyInteractionService: NearbyInteractionService,
        profileService: ProfileService)
    {
        self.motionService = motionService
        self.screenTimeService = screenTimeService
        self.nearbyInteractionService = nearbyInteractionService
        self.profileService = profileService
    }

    // MARK: - State

    var participantStatuses: [UUID: ParticipantStatus] = [:]
    var distractionEvents: [DistractionEvent] = []
    var isLocalDeviceDistracted = false
    var localDistractionSource: DistractionEvent.Source?

    // MARK: - Control

    func startMonitoring(settings: SessionSettings) {
        // TODO: Start motion + screen time monitoring, observe for distraction signals
    }

    func stopMonitoring() {
        // TODO: Stop all monitoring
    }

    func updateRemoteStatus(participantID: UUID, status: ParticipantStatus) {
        participantStatuses[participantID] = status
    }

    // MARK: - Private

    private let motionService: MotionService
    private let screenTimeService: ScreenTimeService
    private let nearbyInteractionService: NearbyInteractionService
    private let profileService: ProfileService
}
