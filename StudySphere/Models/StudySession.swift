import Foundation
import Observation

@Observable
final class StudySession: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionName: String
}

extension StudySession: Equatable {
    static func == (lhs: StudySession, rhs: StudySession) -> Bool {
        return lhs.id == rhs.id
    }
}


