import Foundation
import NearbyInteraction
import os
import VISOR

@Observable
final class LiveNearbyInteractionService: NearbyInteractionService {

    // MARK: - State

    var peerDistances: [String: Float] = [:]
    var peerDirections: [String: SIMD3<Float>] = [:]
    var estimatedPositions: [String: PeerPosition] = [:]
    var isSupported: Bool { NISession.deviceCapabilities.supportsPreciseDistanceMeasurement }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StudySphere", category: "NearbyInteraction")
    private var peerSessions: [String: NISession] = [:]
    private var peerDelegates: [String: SessionDelegate] = [:]
    private let tokenSession = NISession()
    private var cachedTokenData: Data?
    private var centroidX: Double = 0
    private var centroidY: Double = 0
    private var hasCentroid = false

    // MARK: - Sessions

    func startSession(with peerID: String, discoveryTokenData: Data) {
        guard let peerToken = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: discoveryTokenData
        ) else {
            logger.error("Failed to unarchive discovery token for peer \(peerID)")
            return
        }

        let session = NISession()
        let delegate = SessionDelegate(peerID: peerID) { [weak self] peerID, result in
            self?.handleUpdate(peerID: peerID, result: result)
        } onRemoved: { [weak self] peerID in
            self?.handlePeerRemoved(peerID: peerID)
        }
        session.delegate = delegate

        peerSessions[peerID] = session
        peerDelegates[peerID] = delegate

        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        session.run(config)
        logger.info("Started NI session with peer \(peerID)")
    }

    func stopSession(for peerID: String) {
        peerSessions[peerID]?.invalidate()
        peerSessions.removeValue(forKey: peerID)
        peerDelegates.removeValue(forKey: peerID)
        peerDistances.removeValue(forKey: peerID)
        peerDirections.removeValue(forKey: peerID)
        estimatedPositions.removeValue(forKey: peerID)
    }

    func stopAllSessions() {
        for (_, session) in peerSessions {
            session.invalidate()
        }
        peerSessions.removeAll()
        peerDelegates.removeAll()
        peerDistances.removeAll()
        peerDirections.removeAll()
        estimatedPositions.removeAll()
        hasCentroid = false
    }

    func localDiscoveryTokenData() -> Data? {
        if let cachedTokenData { return cachedTokenData }
        guard let token = tokenSession.discoveryToken else {
            logger.warning("NISession discovery token not yet available")
            return nil
        }
        let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        cachedTokenData = data
        return data
    }

    // MARK: - Position

    func calibrateCentroid() {
        guard !estimatedPositions.isEmpty else { return }
        let positions = estimatedPositions.values
        let sumX = positions.reduce(0.0) { $0 + $1.x }
        let sumY = positions.reduce(0.0) { $0 + $1.y }
        let count = Double(positions.count)
        centroidX = sumX / count
        centroidY = sumY / count
        hasCentroid = true
    }

    func isPeerOutsideRadius(_ peerID: String, radiusMeters: Double) -> Bool {
        guard hasCentroid, let peerPos = estimatedPositions[peerID] else { return false }
        let dx = peerPos.x - centroidX
        let dy = peerPos.y - centroidY
        return sqrt(dx * dx + dy * dy) > radiusMeters
    }

    // MARK: - Private

    private func handleUpdate(peerID: String, result: NINearbyObject) {
        if let distance = result.distance {
            peerDistances[peerID] = distance
        }
        if let direction = result.direction {
            peerDirections[peerID] = direction
            if let distance = result.distance {
                let x = Double(direction.x * distance)
                let y = Double(direction.y * distance)
                let distFromCentroid: Double
                if hasCentroid {
                    let dx = x - centroidX
                    let dy = y - centroidY
                    distFromCentroid = sqrt(dx * dx + dy * dy)
                } else {
                    distFromCentroid = 0
                }
                estimatedPositions[peerID] = PeerPosition(x: x, y: y, distanceFromCentroid: distFromCentroid)
            }
        }
    }

    private func handlePeerRemoved(peerID: String) {
        logger.info("Peer removed: \(peerID)")
        peerDistances.removeValue(forKey: peerID)
        peerDirections.removeValue(forKey: peerID)
        estimatedPositions.removeValue(forKey: peerID)
    }
}

// MARK: - Session Delegate

private final class SessionDelegate: NSObject, NISessionDelegate, Sendable {
    let peerID: String
    let onUpdate: @Sendable (String, NINearbyObject) -> Void
    let onRemoved: @Sendable (String) -> Void

    init(peerID: String, onUpdate: @escaping @Sendable (String, NINearbyObject) -> Void, onRemoved: @escaping @Sendable (String) -> Void) {
        self.peerID = peerID
        self.onUpdate = onUpdate
        self.onRemoved = onRemoved
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let nearest = nearbyObjects.first else { return }
        onUpdate(peerID, nearest)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        onRemoved(peerID)
    }
}
