import Foundation

struct StudySession: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let hostName: String
    let hostPeerIDData: Data
    var settings: SessionSettings
    var startedAt: Date?
    var endedAt: Date?
    var participants: [Participant]

    var isActive: Bool { startedAt != nil && endedAt == nil }
}
