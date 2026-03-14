import Foundation

struct Participant: Codable, Equatable, Identifiable, Hashable, Sendable {
    let id: UUID
    let peerIDData: Data
    var name: String
    var avatarSystemName: String = "person.circle.fill"
    var status: ParticipantStatus
    var position: PeerPosition?
}
