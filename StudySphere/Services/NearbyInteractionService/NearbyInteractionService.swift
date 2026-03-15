import Foundation
import VISOR

protocol NearbyInteractionService: AnyObject {
    var peerDistances: [String: Float] { get }
    var peerDirections: [String: SIMD3<Float>] { get }
    var estimatedPositions: [String: PeerPosition] { get }
    var isSupported: Bool { get }

    var centroidX: Double { get }
    var centroidY: Double { get }
    var hasCentroid: Bool { get }

    func prepareSession(for peerID: String) -> Data?
    func runSession(for peerID: String, peerDiscoveryTokenData: Data)
    func stopSession(for peerID: String)
    func stopAllSessions()
    func calibrateCentroid()
    func isPeerOutsideRadius(_ peerID: String, radiusMeters: Double) -> Bool

    func startDistanceMonitoring(
        for peerID: String,
        baselineNIDistance: Float,
        baselineCentroidDistance: Double,
        radiusMeters: Double,
        onBoundaryCross: @escaping @Sendable (Bool) -> Void
    )
    func stopDistanceMonitoring()
}
