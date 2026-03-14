import Foundation

final class StudySession: Codable, Identifiable, Sendable {
    let id: UUID
    let hostName: String
    let hostPeerIDData: Data
    var settings: SessionSettings
    var startedAt: Date?
    var endedAt: Date?
    var participants: [Participant]
    
    var isActive: Bool { startedAt != nil && endedAt == nil }
}

extension StudySession: Equatable {
    static func == (lhs: StudySession, rhs: StudySession) -> Bool {
        return lhs.id == rhs.id
    }
}
