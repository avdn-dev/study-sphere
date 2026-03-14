import SwiftUI

struct MetaballView: View {
    let participants: [Participant]
    let positions: [String: PeerPosition]
    let statuses: [UUID: ParticipantStatus]
    let radiusMeters: Double

    var body: some View {
//        Canvas { context, size in
//            let center = CGPoint(x: size.width / 2, y: size.height / 2)
//            let displayRadius = min(size.width, size.height) / 2.5
//
//            // Draw focus circle boundary
//            let circlePath = Path(ellipseIn: CGRect(
//                x: center.x - displayRadius,
//                y: center.y - displayRadius,
//                width: displayRadius * 2,
//                height: displayRadius * 2))
//            context.stroke(circlePath, with: .color(.blue.opacity(0.3)), lineWidth: 2)
//            context.fill(circlePath, with: .color(.blue.opacity(0.05)))
//
//            // Draw participant nodes
//            for participant in participants {
//                let status = statuses[participant.id] ?? participant.status
//                let color: Color = switch status {
//                case .focused: .green
//                case .distracted, .outsideCircle: .red
//                case .disconnected: .gray
//                }
//
//                // Position node based on peer position or distribute evenly
//                let nodeCenter: CGPoint
//                if let pos = positions[participant.peerIDData.base64EncodedString()] {
//                    let scale = displayRadius / radiusMeters
//                    nodeCenter = CGPoint(
//                        x: center.x + pos.x * scale,
//                        y: center.y + pos.y * scale)
//                } else {
//                    nodeCenter = center
//                }
//
//                let nodeRadius: CGFloat = 15
//                let nodePath = Path(ellipseIn: CGRect(
//                    x: nodeCenter.x - nodeRadius,
//                    y: nodeCenter.y - nodeRadius,
//                    width: nodeRadius * 2,
//                    height: nodeRadius * 2))
//                context.fill(nodePath, with: .color(color.opacity(0.8)))
//                context.stroke(nodePath, with: .color(color), lineWidth: 2)
//            }
//        }
        EmptyView()
    }
}
