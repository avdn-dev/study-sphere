import Foundation
import Observation

@Observable
final class StudySession: Codable, Identifiable, Sendable {
    let id: UUID
    let settings: SessionSettings
    let maxSize: Int
    var isActive: Bool

    init(id: UUID, settings: SessionSettings, maxSize: Int, isActive: Bool = false) {
        self.id = id
        self.settings = settings
        precondition((1...8).contains(maxSize), "Invalid study session size")
        self.maxSize = maxSize
        self.isActive = isActive
    }
}

extension StudySession: Equatable {
    static func == (lhs: StudySession, rhs: StudySession) -> Bool {
        return lhs.id == rhs.id
    }
}


