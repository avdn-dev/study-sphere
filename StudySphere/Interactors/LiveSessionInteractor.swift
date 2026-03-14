import Foundation
import VISOR

@Observable
final class LiveSessionInteractor: SessionInteractor {

    init(
        multipeerService: MultipeerService,
        nearbyInteractionService: NearbyInteractionService,
        motionService: MotionService,
        screenTimeService: ScreenTimeService,
        profileService: ProfileService,
        permissionsService: PermissionsService)
    {
        self.multipeerService = multipeerService
        self.nearbyInteractionService = nearbyInteractionService
        self.motionService = motionService
        self.screenTimeService = screenTimeService
        self.profileService = profileService
        self.permissionsService = permissionsService
    }

    // MARK: - State

    var activeSession: StudySession?
    var participants: [Participant] = []
    var isHost = false
    var remainingTime: TimeInterval?
    var isCalibrated = false
    var isScreenTimeAuthorized: Bool { permissionsService.isScreenTimeAuthorized }

    // MARK: - Host

    func createSession(settings: SessionSettings) async {
        // TODO: Create session, start advertising via MultipeerService
    }

    func startSession() async {
        // TODO: Begin focus mode — calibrate NI, start motion/screen time monitoring
    }

    func endSession() async {
        // TODO: End session, disconnect all peers, stop monitoring
    }

    // MARK: - Joiner

    func joinSession(host: DiscoveredSession) async {
        // TODO: Join via MultipeerService, exchange NI tokens
    }

    func leaveSession() async {
        // TODO: Disconnect from session, stop monitoring
    }

    // MARK: - Screen Time

    func requestScreenTimeAuthorization() async throws {

    }

    // MARK: - Private

    private let multipeerService: MultipeerService
    private let nearbyInteractionService: NearbyInteractionService
    private let motionService: MotionService
    private let screenTimeService: ScreenTimeService
    private let profileService: ProfileService
    private let permissionsService: PermissionsService
}
