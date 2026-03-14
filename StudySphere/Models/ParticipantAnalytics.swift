import Foundation

struct ParticipantAnalytics: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    var name: String
    /// 0.0 – 1.0
    var focusScore: Double
    var focusDurationSeconds: TimeInterval
    var distractionCount: Int
}
