import Foundation
import VISOR

@Observable
final class LiveSessionInteractor: SessionInteractor {

    init(
        multipeerService: any MultipeerService,
        nearbyInteractionService: any NearbyInteractionService,
        motionService: any MotionService,
        screenTimeService: any ScreenTimeService,
        profileService: any ProfileService)
    {
        self.multipeerService = multipeerService
        self.nearbyInteractionService = nearbyInteractionService
        self.motionService = motionService
        self.screenTimeService = screenTimeService
        self.profileService = profileService
    }

    // MARK: - State

    var activeSession: StudySession?
    var participants: [Participant] = []
    var isHost = false
    var remainingTime: TimeInterval?
    var isCalibrated = false
    var isScreenTimeAuthorized: Bool { screenTimeService.isAuthorized }

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

//    func joinSession(host: DiscoveredSession) async {
//        // TODO: Join via MultipeerService, exchange NI tokens
//    }

    func leaveSession() async {
        // TODO: Disconnect from session, stop monitoring
    }

    // MARK: - Screen Time

    func requestScreenTimeAuthorization() async throws {
        try await screenTimeService.requestAuthorization()
    }

    // MARK: - Private

    private let multipeerService: any MultipeerService
    private let nearbyInteractionService: any NearbyInteractionService
    private let motionService: any MotionService
    private let screenTimeService: any ScreenTimeService
    private let profileService: any ProfileService
}
