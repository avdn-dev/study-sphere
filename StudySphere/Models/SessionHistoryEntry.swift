import Foundation

struct SessionHistoryEntry: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let sessionName: String
    let date: Date
    let durationSeconds: TimeInterval
    let participantCount: Int
    let distractionCount: Int
    let focusScore: Double
}
