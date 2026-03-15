import AudioToolbox
import Foundation
import VISOR

@Observable
final class LiveDistractionInteractor: DistractionInteractor {

    init(
        motionService: any MotionService,
        audioService: any AudioService,
        screenTimeService: any ScreenTimeService,
        nearbyInteractionService: any NearbyInteractionService,
        profileService: any ProfileService)
    {
        self.motionService = motionService
        self.audioService = audioService
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
        if settings.requireStillness {
            motionService.startMonitoring(sensitivity: 0.6)
            startMotionObservation()
        }
    }

    func stopMonitoring() {
        motionObservationTask?.cancel()
        motionObservationTask = nil
        motionService.stopMonitoring()
        isLocalDeviceDistracted = false
        localDistractionSource = nil
    }

    func updateRemoteStatus(participantID: UUID, status: ParticipantStatus) {
        participantStatuses[participantID] = status
    }

    // MARK: - Private

    private let motionService: any MotionService
    private let audioService: any AudioService
    private let screenTimeService: any ScreenTimeService
    private let nearbyInteractionService: any NearbyInteractionService
    private let profileService: any ProfileService

    private var motionObservationTask: Task<Void, Never>?

    private func startMotionObservation() {
        motionObservationTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                guard let self else { break }

                let wasStationary = self.motionService.isStationary

                // Wait for isStationary to change
                await withCheckedContinuation { continuation in
                    withObservationTracking {
                        _ = self.motionService.isStationary
                    } onChange: {
                        continuation.resume()
                    }
                }

                guard !Task.isCancelled else { break }

                let isNowStationary = self.motionService.isStationary

                if wasStationary && !isNowStationary {
                    self.handleMotionDistraction()
                } else if isNowStationary && self.localDistractionSource == .deviceMotion {
                    self.isLocalDeviceDistracted = false
                    self.localDistractionSource = nil
                }
            }
        }
    }

    private func handleMotionDistraction() {
        isLocalDeviceDistracted = true
        localDistractionSource = .deviceMotion

        let event = DistractionEvent(
            id: UUID(),
            timestamp: Date(),
            source: .deviceMotion,
            participantID: profileService.profile?.id ?? UUID()
        )
        distractionEvents.append(event)

        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }
}
