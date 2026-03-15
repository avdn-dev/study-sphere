import MetalKit
import SwiftUI

struct MetalMetaballView: UIViewRepresentable {
    let participants: [Participant]
    let positions: [String: PeerPosition]
    let statuses: [UUID: ParticipantStatus]
    let radiusMeters: Double

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.isOpaque = false
        mtkView.backgroundColor = .clear
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = false
        mtkView.isPaused = false

        if let renderer = MetalMetaballRenderer(mtkView: mtkView) {
            context.coordinator.renderer = renderer
            mtkView.delegate = renderer
        }
        return mtkView
    }

    func updateUIView(_ mtkView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }

        let coord = context.coordinator
        var nodes: [MetaballNodeBridge] = []
        var focusSum: Float = 0

        for participant in participants {
            let status = statuses[participant.id] ?? participant.status
            let strength: Float = switch status {
            case .focused: 1.0
            case .distracted: 0.2
            case .outsideCircle: 0.4
            case .disconnected: 0.1
            case .reconnecting: 0.15
            }

            let key = participant.peerIDData.base64EncodedString()
            let rawPos: SIMD2<Float>
            if let pos = positions[key] {
                rawPos = SIMD2<Float>(Float(pos.x), Float(pos.y))
            } else if let pos = participant.position {
                rawPos = SIMD2<Float>(Float(pos.x), Float(pos.y))
            } else {
                rawPos = .zero
            }

            // EMA smoothing for both position and strength
            let smoothedPos = coord.smoothPosition(id: participant.id, target: rawPos)
            let smoothedStrength = coord.smoothStrength(id: participant.id, target: strength)

            nodes.append(MetaballNodeBridge(position: smoothedPos, strength: smoothedStrength))
            focusSum += smoothedStrength
        }

        // Re-center nodes around the centroid of all participants
        if !nodes.isEmpty {
            let centroid = nodes.reduce(SIMD2<Float>.zero) { $0 + $1.position } / Float(nodes.count)
            for i in nodes.indices {
                nodes[i].position -= centroid
            }
        }

        let groupFocus = nodes.isEmpty ? 1.0 : focusSum / Float(nodes.count)
        renderer.updateNodes(nodes, groupFocus: groupFocus, radiusMeters: Float(radiusMeters))
    }

    // MARK: - Coordinator

    final class Coordinator {
        var renderer: MetalMetaballRenderer?
        private var smoothedPositions: [UUID: SIMD2<Float>] = [:]
        private var smoothedStrengths: [UUID: Float] = [:]
        private let positionAlpha: Float = 0.15   // ~110ms smoothing at 60fps
        private let strengthAlpha: Float = 0.08   // slower ~200ms for gentle size transitions

        func smoothPosition(id: UUID, target: SIMD2<Float>) -> SIMD2<Float> {
            if let current = smoothedPositions[id] {
                let result = current + positionAlpha * (target - current)
                smoothedPositions[id] = result
                return result
            } else {
                smoothedPositions[id] = target
                return target
            }
        }

        func smoothStrength(id: UUID, target: Float) -> Float {
            if let current = smoothedStrengths[id] {
                let result = current + strengthAlpha * (target - current)
                smoothedStrengths[id] = result
                return result
            } else {
                smoothedStrengths[id] = target
                return target
            }
        }
    }
}
