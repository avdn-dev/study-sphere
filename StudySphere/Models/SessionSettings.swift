import Foundation

struct SessionSettings: Codable, Equatable, Sendable {
    var sessionName: String
    var radiusMeters: Double
    var requireStillness: Bool
    var blockedAppData: Data?
}
