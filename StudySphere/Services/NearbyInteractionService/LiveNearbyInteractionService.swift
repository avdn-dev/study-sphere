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
    private var centroidX: Double = 0
    private var centroidY: Double = 0
    private var hasCentroid = false

    // MARK: - Sessions

    func prepareSession(for peerID: String) -> Data? {
        // If a session already exists for this peer, return its token
        if let existing = peerSessions[peerID] {
            guard let token = existing.discoveryToken else {
                logger.warning("Existing session for \(peerID) has no discovery token")
                return nil
            }
            return try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
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

        guard let token = session.discoveryToken else {
            logger.warning("New NISession for \(peerID) has no discovery token")
            return nil
        }
        let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true)
        logger.info("Prepared NI session for peer \(peerID)")
        return data
    }

    func runSession(for peerID: String, peerDiscoveryTokenData: Data) {
        guard let session = peerSessions[peerID] else {
            logger.error("No prepared session for peer \(peerID) — call prepareSession first")
            return
        }
        guard let peerToken = try? NSKeyedUnarchiver.unarchivedObject(
            ofClass: NIDiscoveryToken.self,
            from: peerDiscoveryTokenData
        ) else {
            logger.error("Failed to unarchive discovery token for peer \(peerID)")
            return
        }

        let config = NINearbyPeerConfiguration(peerToken: peerToken)
        session.run(config)
        logger.info("Running NI session with peer \(peerID)")
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
            logger.debug("NI distance update — peer: \(peerID), distance: \(String(format: "%.2f", distance))m")
        } else {
            logger.debug("NI update — peer: \(peerID), distance: nil")
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
                logger.debug("NI position update — peer: \(peerID), x: \(String(format: "%.2f", x)), y: \(String(format: "%.2f", y)), centroidDist: \(String(format: "%.2f", distFromCentroid))")
            }
        } else {
            logger.debug("NI update — peer: \(peerID), direction: nil")
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
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "StudySphere", category: "NearbyInteraction")

    init(peerID: String, onUpdate: @escaping @Sendable (String, NINearbyObject) -> Void, onRemoved: @escaping @Sendable (String) -> Void) {
        self.peerID = peerID
        self.onUpdate = onUpdate
        self.onRemoved = onRemoved
    }

    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        logger.info("NI didUpdate — peer: \(self.peerID), objectCount: \(nearbyObjects.count)")
        guard let nearest = nearbyObjects.first else { return }
        onUpdate(peerID, nearest)
    }

    func session(_ session: NISession, didRemove nearbyObjects: [NINearbyObject], reason: NINearbyObject.RemovalReason) {
        logger.info("NI didRemove — peer: \(self.peerID), reason: \(String(describing: reason))")
        onRemoved(peerID)
    }

    func session(_ session: NISession, didInvalidateWith error: Error) {
        logger.error("NI session invalidated — peer: \(self.peerID), error: \(error.localizedDescription)")
    }

    func sessionSuspensionEnded(_ session: NISession) {
        logger.info("NI session suspension ended — peer: \(self.peerID)")
    }

    func sessionWasSuspended(_ session: NISession) {
        logger.warning("NI session suspended — peer: \(self.peerID)")
    }
}
