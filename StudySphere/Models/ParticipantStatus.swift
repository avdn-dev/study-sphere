import Foundation

enum ParticipantStatus: String, Codable, Equatable, Sendable {
    case focused
    case distracted
    case outsideCircle
    case disconnected
    case reconnecting
}
