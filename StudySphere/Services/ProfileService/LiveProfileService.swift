import Foundation
import MultipeerConnectivity
import VISOR

@Observable
final class LiveProfileService: ProfileService {

    // MARK: - State

    var profile: UserProfile?
    var displayName: String { profile?.name ?? "Student" }
    var peerID: MCPeerID? { profile?.peerID }
    var sessionHistory: [SessionHistoryEntry] = []

    // MARK: - Profile

    func load() {
        // TODO: Load profile from UserDefaults/file
    }

    func saveProfile(name: String, avatarSystemName: String) {
        // TODO: Create/update profile with archived MCPeerID and persist
    }

    // MARK: - History

    func addHistoryEntry(_ entry: SessionHistoryEntry) {
        // TODO: Append and persist
    }

    func clearHistory() {
        // TODO: Clear persisted history
        sessionHistory = []
    }
}
