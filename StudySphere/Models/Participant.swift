import Foundation

struct Participant: Codable, Equatable, Identifiable, Hashable, Sendable {
    let id: UUID
    let peerIDData: Data
    var name: String
    var avatarSystemName: String = "person.crop.circle.fill"
    var avatarImageData: Data?
    var status: ParticipantStatus
    var position: PeerPosition?
}
