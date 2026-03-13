import Foundation
import NearbyInteraction
import VISOR

@Observable
final class LiveNearbyInteractionService: NearbyInteractionService {

    // MARK: - State

    var peerDistances: [String: Float] = [:]
    var peerDirections: [String: SIMD3<Float>] = [:]
    var estimatedPositions: [String: PeerPosition] = [:]
    var isSupported: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }

    // MARK: - Sessions

    func startSession(with peerID: String, discoveryTokenData: Data) {
        // TODO: Create NISession and run with peer token
    }

    func stopSession(for peerID: String) {
        // TODO: Invalidate NISession for peer
    }

    func stopAllSessions() {
        // TODO: Invalidate all NISessions
    }

    func localDiscoveryTokenData() -> Data? {
        // TODO: Return archived local discovery token
        nil
    }

    // MARK: - Position

    func calibrateCentroid() {
        // TODO: Set current peer positions as centroid reference
    }

    func isPeerOutsideRadius(_ peerID: String, radiusMeters: Double) -> Bool {
        // TODO: Check if peer position exceeds radius from centroid
        false
    }
}
