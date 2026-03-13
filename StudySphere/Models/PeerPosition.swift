import Foundation

struct PeerPosition: Codable, Equatable, Sendable, Hashable {
    var x: Double
    var y: Double
    var distanceFromCentroid: Double
}
