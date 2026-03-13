import Foundation

struct DistractionEvent: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let source: Source
    let participantID: UUID

    enum Source: String, Codable, Equatable, Sendable {
        case blockedAppUsage
        case deviceMotion
        case leftCircle
    }
}
