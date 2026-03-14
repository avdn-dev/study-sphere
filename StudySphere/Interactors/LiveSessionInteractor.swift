import Foundation
import VISOR

@Observable
final class LiveSessionInteractor: SessionInteractor {

    init(
        multipeerService: any MultipeerService,
        nearbyInteractionService: any NearbyInteractionService,
        motionService: any MotionService,
        screenTimeService: any ScreenTimeService,
        profileService: any ProfileService,
        permissionsService: any PermissionsService,
        studySessionService: any StudySessionService)
    {
        self.multipeerService = multipeerService
        self.nearbyInteractionService = nearbyInteractionService
        self.motionService = motionService
        self.screenTimeService = screenTimeService
        self.profileService = profileService
        self.permissionsService = permissionsService
        self.studySessionService = studySessionService
    }

    // MARK: - State

    var activeSession: StudySession? {
        studySessionService.activeSession
    }

    var participants: [Participant] {
        studySessionService.participants
    }

    var isHost: Bool {
        studySessionService.isLeader
    }

    var phase: StudySessionPhase {
        studySessionService.phase
    }

    var remainingTime: TimeInterval?
    var isCalibrated = false
    var isScreenTimeAuthorized: Bool { permissionsService.isScreenTimeAuthorized }

    // MARK: - Host

    func createSession(settings: SessionSettings) async {
        let session = StudySession(
            id: UUID(),
            settings: settings,
            maxSize: 8
        )

        do {
            try multipeerService.setCurrentSession(session)
            try multipeerService.startLookingForParticipants()
        } catch {
            return
        }

        await studySessionService.hostSession(session)
    }

    func startSession() async {
        guard let session = studySessionService.activeSession else { return }

        await studySessionService.startSession()

        // Calibrate NI centroid
        nearbyInteractionService.calibrateCentroid()
        isCalibrated = true

        // Apply screen time shields if configured
        if session.settings.blockedAppData != nil {
            screenTimeService.applyShields()
        }

        // Start countdown timer
        startCountdownTimer(duration: session.settings.durationSeconds)
    }

    func endSession() async {
        await studySessionService.endSession()
        stopCountdownTimer()
        screenTimeService.removeShields()
        nearbyInteractionService.stopAllSessions()
        multipeerService.stopLookingForParticipants()
        isCalibrated = false
        remainingTime = nil
    }

    // MARK: - Joiner

    func leaveSession() async {
        await studySessionService.leaveSession()
        stopCountdownTimer()
        screenTimeService.removeShields()
        nearbyInteractionService.stopAllSessions()
        multipeerService.stopLookingForRooms()
        isCalibrated = false
        remainingTime = nil
    }

    // MARK: - Screen Time

    func requestScreenTimeAuthorization() async throws {
        try await permissionsService.requestScreenTimesPermission()
    }

    // MARK: - Private

    private let multipeerService: any MultipeerService
    private let nearbyInteractionService: any NearbyInteractionService
    private let motionService: any MotionService
    private let screenTimeService: any ScreenTimeService
    private let profileService: any ProfileService
    private let permissionsService: any PermissionsService
    private let studySessionService: any StudySessionService

    private var countdownTask: Task<Void, Never>?

    private func startCountdownTimer(duration: TimeInterval) {
        remainingTime = duration
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            let startDate = Date()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                let elapsed = Date().timeIntervalSince(startDate)
                let remaining = duration - elapsed
                if remaining <= 0 {
                    await MainActor.run {
                        self.remainingTime = 0
                    }
                    await self.endSession()
                    break
                }
                await MainActor.run {
                    self.remainingTime = remaining
                }
            }
        }
    }

    private func stopCountdownTimer() {
        countdownTask?.cancel()
        countdownTask = nil
    }
}
