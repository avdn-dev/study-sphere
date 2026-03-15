import Foundation
import UIKit
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
        startPhaseObservation()
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

    var elapsedTime: TimeInterval?
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

        // Start stopwatch
        startStopwatch()
    }

    func endSession() async {
        await studySessionService.endSession()
        stopStopwatch()
        screenTimeService.removeShields()
        nearbyInteractionService.stopAllSessions()
        multipeerService.stopLookingForParticipants()
        isCalibrated = false
        elapsedTime = nil
    }

    // MARK: - Joiner

    func leaveSession() async {
        await studySessionService.leaveSession()
        stopStopwatch()
        screenTimeService.removeShields()
        nearbyInteractionService.stopAllSessions()
        multipeerService.stopLookingForRooms()
        isCalibrated = false
        elapsedTime = nil
    }

    func leaveSessionGracefully() async {
        await studySessionService.leaveSessionGracefully()
        stopStopwatch()
        screenTimeService.removeShields()
        nearbyInteractionService.stopAllSessions()
        multipeerService.stopLookingForParticipants()
        isCalibrated = false
        elapsedTime = nil
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

    private var stopwatchTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var phaseObservationTask: Task<Void, Never>?

    /// Observe phase changes to start/stop the stopwatch on the peer side
    private func startPhaseObservation() {
        phaseObservationTask = Task { [weak self] in
            var previousPhase: StudySessionPhase = .idle
            while !Task.isCancelled {
                guard let self else { break }
                let currentPhase = self.studySessionService.phase

                if currentPhase != previousPhase {
                    // Peer side: start stopwatch when session becomes active
                    if currentPhase == .active && previousPhase != .active && !self.studySessionService.isLeader {
                        await MainActor.run {
                            self.startStopwatch()
                        }
                    }
                    // Stop stopwatch when session ends
                    if currentPhase == .ended && previousPhase != .ended {
                        await MainActor.run {
                            self.stopStopwatch()
                            self.elapsedTime = nil
                        }
                    }
                    previousPhase = currentPhase
                }
                try? await Task.sleep(for: .milliseconds(250))
            }
        }
    }

    func startStopwatch() {
        stopwatchTask?.cancel()
        stopwatchTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                guard let startDate = self.studySessionService.sessionStartDate else { break }
                let elapsed = Date().timeIntervalSince(startDate)
                await MainActor.run {
                    self.elapsedTime = elapsed
                }
            }
        }
    }

    private func stopStopwatch() {
        stopwatchTask?.cancel()
        stopwatchTask = nil
    }

    // MARK: - Background Task Extension

    func handleAppDidEnterBackground() {
        let phase = studySessionService.phase
        guard phase == .active || phase == .lobby || phase == .joined || phase == .leaderReconnecting else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func handleAppWillEnterForeground() {
        endBackgroundTask()
        studySessionService.handleReturnToForeground()
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }
}
