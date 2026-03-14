import Foundation
import MultipeerConnectivity

struct UserProfile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var avatarSystemName: String
    /// Archived MCPeerID representing a stable local peer identity.
    var peerIDData: Data

    var peerID: MCPeerID? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: peerIDData)
    }
}
