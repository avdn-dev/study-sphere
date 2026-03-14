import Foundation
import Observation

@Observable
final class StudySession: Codable, Identifiable, Sendable {
    let id: UUID
    let sessionName: String
    let maxSize: Int
    
    init(id: UUID, sessionName: String, maxSize: Int) {
        self.id = id
        self.sessionName = sessionName
        precondition((1...8).contains(maxSize), "Invalid study session size")
        self.maxSize = maxSize
    }
}

extension StudySession: Equatable {
    static func == (lhs: StudySession, rhs: StudySession) -> Bool {
        return lhs.id == rhs.id
    }
}


