import Foundation
import VISOR

@Stubbable
@Spyable
protocol NearbyInteractionService: AnyObject {
    var peerDistances: [String: Float] { get }
    var peerDirections: [String: SIMD3<Float>] { get }
    var estimatedPositions: [String: PeerPosition] { get }
    var isSupported: Bool { get }

    func startSession(with peerID: String, discoveryTokenData: Data)
    func stopSession(for peerID: String)
    func stopAllSessions()
    func localDiscoveryTokenData() -> Data?
    func calibrateCentroid()
    func isPeerOutsideRadius(_ peerID: String, radiusMeters: Double) -> Bool
}

#if DEBUG
extension SpyNearbyInteractionService.Call: Equatable {
    public static func == (lhs: SpyNearbyInteractionService.Call, rhs: SpyNearbyInteractionService.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
