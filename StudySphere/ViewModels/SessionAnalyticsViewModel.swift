import Foundation
import UIKit
import VISOR

@Observable
@ViewModel
final class SessionAnalyticsViewModel {

    typealias Action = Never

    struct State: Equatable {
        @Bound(\SessionAnalyticsViewModel.profileService) var profile: UserProfile?
        @Bound(\SessionAnalyticsViewModel.profileService) var profileImage: UIImage?
        @Bound(\SessionAnalyticsViewModel.profileService) var sessionHistory: [SessionHistoryEntry] = []
    }

    var state = State()

    // MARK: - Derived data (most-recent session)

    var latestSession: SessionHistoryEntry? {
        state.sessionHistory.first
    }

    var focusMVP: ParticipantAnalytics? {
        latestSession?.participantAnalytics.max(by: { $0.focusScore < $1.focusScore })
    }

    /// Average focus score across all participants in the latest session.
    var overallSyncRate: Double {
        guard let analytics = latestSession?.participantAnalytics, !analytics.isEmpty else {
            return latestSession?.focusScore ?? 0
        }
        return analytics.reduce(0) { $0 + $1.focusScore } / Double(analytics.count)
    }

    var totalFlowTime: TimeInterval {
        latestSession?.durationSeconds ?? 0
    }

    /// (completed, goal) -- total sessions completed vs. a milestone goal of 15.
    var collectiveMilestones: (completed: Int, total: Int) {
        (min(state.sessionHistory.count, 15), 15)
    }

    /// Heuristic: each distraction event ~2 min recovery.
    var groupRecoveryTime: TimeInterval {
        guard let session = latestSession else { return 0 }
        let totalDistractions = session.participantAnalytics.reduce(0) { $0 + $1.distractionCount }
        return Double(totalDistractions) * 120
    }

    var averageRecoveryTime: TimeInterval {
        let sessions = state.sessionHistory
        guard sessions.count > 1 else { return groupRecoveryTime }
        let total = sessions.reduce(0.0) { sum, s in
            sum + Double(s.participantAnalytics.reduce(0) { $0 + $1.distractionCount }) * 120
        }
        return total / Double(sessions.count)
    }

    var recoveryTimeDelta: TimeInterval {
        groupRecoveryTime - averageRecoveryTime
    }

    var peerContributions: [ParticipantAnalytics] {
        (latestSession?.participantAnalytics ?? []).sorted { $0.focusScore > $1.focusScore }
    }

    var topAccountabilityPartner: ParticipantAnalytics? {
        guard let userName = state.profile?.name else { return peerContributions.first }
        return peerContributions.first { $0.name != userName }
    }

    var totalPeerFocusHours: Int {
        let total = state.sessionHistory.reduce(0.0) { sum, s in
            sum + s.participantAnalytics.reduce(0.0) { $0 + $1.focusDurationSeconds }
        }
        return Int(total / 3600)
    }

    // MARK: - Private

    private let profileService: any ProfileService
}
