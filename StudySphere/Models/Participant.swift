import Foundation

struct Participant: Codable, Equatable, Identifiable, Hashable, Sendable {
    let id: UUID
    let peerIDData: Data
    var name: String
    var status: ParticipantStatus
    var position: PeerPosition?
}
