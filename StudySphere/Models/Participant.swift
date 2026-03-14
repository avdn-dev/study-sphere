import Foundation

struct Participant: Codable, Equatable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var status: ParticipantStatus
    var position: PeerPosition?
}
