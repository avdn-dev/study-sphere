import Foundation
import VISOR

@Observable
final class LiveDistractionInteractor: DistractionInteractor {

    init(
        motionService: any MotionService,
        screenTimeService: any ScreenTimeService,
        nearbyInteractionService: any NearbyInteractionService,
        profileService: any ProfileService)
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

    private let motionService: any MotionService
    private let screenTimeService: any ScreenTimeService
    private let nearbyInteractionService: any NearbyInteractionService
    private let profileService: any ProfileService
}
