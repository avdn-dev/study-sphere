import Foundation
import MultipeerConnectivity

struct UserProfile: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    /// JPEG (or PNG) data for profile avatar; nil means use placeholder.
    var avatarImageData: Data?
    /// Archived MCPeerID representing a stable local peer identity.
    var peerIDData: Data

    var peerID: MCPeerID? {
        try? NSKeyedUnarchiver.unarchivedObject(ofClass: MCPeerID.self, from: peerIDData)
    }

    init(id: UUID, name: String, avatarImageData: Data?, peerIDData: Data) {
        self.id = id
        self.name = name
        self.avatarImageData = avatarImageData
        self.peerIDData = peerIDData
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarImageData = try container.decodeIfPresent(Data.self, forKey: .avatarImageData)
        peerIDData = try container.decode(Data.self, forKey: .peerIDData)
        // Ignore legacy avatarSystemName key so old stored profiles still decode.
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, avatarImageData, peerIDData
    }
}
