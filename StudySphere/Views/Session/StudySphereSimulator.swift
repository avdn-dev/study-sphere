import Foundation
import QuartzCore

/// Pure movement generator — takes participant keys and produces
/// organic position updates. Does NOT own participants or statuses.
@Observable
final class StudySphereSimulator {

    /// The only output: position updates keyed by base64-encoded peerIDData.
    private(set) var positions: [String: PeerPosition] = [:]

    private var displayLink: CADisplayLink?
    private let startTime = CFAbsoluteTimeGetCurrent()

    private var participantKeys: [String] = []
    private var baseAngles: [Double] = []
    private let baseRadius: Double = 2.5 // meters from center

    // MARK: - Public API

    /// Call whenever the participant list changes so movement
    /// is generated for the correct set of keys.
    func updateParticipants(_ participants: [Participant]) {
        participantKeys = participants.map { $0.peerIDData.base64EncodedString() }
        let count = max(participantKeys.count, 1)
        baseAngles = (0..<participantKeys.count).map {
            Double($0) * (.pi * 2.0 / Double(count))
        }
    }

    func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
    }

    // MARK: - Display link

    @objc private func tick() {
        let t = CFAbsoluteTimeGetCurrent() - startTime
        updatePositions(time: t)
    }

    // MARK: - Movement generation

    private func updatePositions(time t: Double) {
        for i in participantKeys.indices {
            let key = participantKeys[i]

            // Slow orbit + two overlapping sinusoidal drifts for organic noise
            let angle = baseAngles[i] + t * 0.05
            let drift1 = sin(t * 0.3 + Double(i) * 1.7) * 0.4
            let drift2 = sin(t * 0.17 + Double(i) * 2.3) * 0.25
            let radius = baseRadius + drift1 + drift2

            // Micro-drift: high-frequency, low-amplitude jitter
            let microX = sin(t * 1.3 + Double(i) * 4.1) * 0.08
                       + sin(t * 2.7 + Double(i) * 1.9) * 0.04
            let microY = sin(t * 1.1 + Double(i) * 3.3) * 0.08
                       + cos(t * 2.1 + Double(i) * 2.7) * 0.04

            let x = cos(angle) * radius + microX
            let y = sin(angle) * radius + microY

            positions[key] = PeerPosition(x: x, y: y, distanceFromCentroid: radius)
        }
    }
}
