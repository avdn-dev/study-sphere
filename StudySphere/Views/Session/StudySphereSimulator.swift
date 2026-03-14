import Foundation
import QuartzCore

@Observable
final class StudySphereSimulator {

    private(set) var participants: [Participant] = []
    private(set) var positions: [String: PeerPosition] = [:]
    private(set) var statuses: [UUID: ParticipantStatus] = [:]

    private var displayLink: CADisplayLink?
    private let startTime = CFAbsoluteTimeGetCurrent()

    // Fixed IDs for stable identity
    private let ids: [UUID] = (0..<5).map { _ in UUID() }

    private let names = ["Alice", "Bob", "Carol", "Dave", "Eve"]
    private let avatars = [
        "person.crop.circle.fill",
        "figure.walk.circle.fill",
        "star.circle.fill",
        "heart.circle.fill",
        "bolt.circle.fill"
    ]

    // Base angles for circular arrangement (radians)
    private let baseAngles: [Double] = (0..<5).map { Double($0) * (.pi * 2.0 / 5.0) }
    private let baseRadius: Double = 2.5 // meters from center (~50% of default 5m radius)

    init() {
        // Build initial participants
        for i in 0..<5 {
            let peerData = ids[i].uuidString.data(using: .utf8)!
            participants.append(Participant(
                id: ids[i],
                peerIDData: peerData,
                name: names[i],
                avatarSystemName: avatars[i],
                status: .focused
            ))
            statuses[ids[i]] = .focused
        }
        updatePositions(time: 0)
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

    @objc private func tick() {
        let t = CFAbsoluteTimeGetCurrent() - startTime
        updatePositions(time: t)
        updateStatuses(time: t)
    }

    private func updatePositions(time t: Double) {
        for i in 0..<5 {
            let key = participants[i].peerIDData.base64EncodedString()

            // Slow orbit + two overlapping sinusoidal drifts for organic noise
            let angle = baseAngles[i] + t * 0.05
            let drift1 = sin(t * 0.3 + Double(i) * 1.7) * 0.4
            let drift2 = sin(t * 0.17 + Double(i) * 2.3) * 0.25

            var radius = baseRadius + drift1 + drift2

            // Dave (index 3) periodically drifts far away on a ~42s cycle
            if i == 3 {
                let davePhase = (sin(t * .pi * 2.0 / 42.0) + 1.0) / 2.0 // 0…1
                let daveExtra = davePhase * 3.5 // up to 3.5m extra → ~6m, beyond 5m radius
                radius += daveExtra
            }

            // Eve (index 4) fully leaves the circle on a ~55s cycle
            // When she's out, everyone's group focus drops → blob shifts red
            if i == 4 {
                let evePhase = (sin(t * .pi * 2.0 / 55.0) + 1.0) / 2.0
                let eveExtra = evePhase * 4.5 // up to 4.5m extra → ~7m, well outside radius
                radius += eveExtra
            }

            // Micro-drift: high-frequency, low-amplitude jitter so nodes never sit still
            let microX = sin(t * 1.3 + Double(i) * 4.1) * 0.08
                       + sin(t * 2.7 + Double(i) * 1.9) * 0.04
            let microY = sin(t * 1.1 + Double(i) * 3.3) * 0.08
                       + cos(t * 2.1 + Double(i) * 2.7) * 0.04

            let x = cos(angle) * radius + microX
            let y = sin(angle) * radius + microY

            let pos = PeerPosition(x: x, y: y, distanceFromCentroid: radius)
            positions[key] = pos
            participants[i].position = pos
        }
    }

    private func updateStatuses(time t: Double) {
        for i in 0..<5 {
            var status: ParticipantStatus = .focused

            // Carol (index 2) cycles distracted on a ~20s cycle
            if i == 2 {
                let carolPhase = sin(t * .pi * 2.0 / 20.0)
                status = carolPhase > 0.3 ? .distracted : .focused
            }

            // Dave (index 3) and Eve (index 4) show outsideCircle when beyond radius
            if i == 3 || i == 4 {
                if let pos = positions[participants[i].peerIDData.base64EncodedString()] {
                    if pos.distanceFromCentroid > 5.0 {
                        status = .outsideCircle
                    } else if pos.distanceFromCentroid > 4.0 {
                        status = .distracted
                    }
                }
            }

            statuses[ids[i]] = status
            participants[i].status = status
        }
    }
}
