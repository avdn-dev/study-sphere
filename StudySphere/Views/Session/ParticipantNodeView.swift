import SwiftUI

struct ParticipantNodeView: View {
    let participant: Participant
    let status: ParticipantStatus

    var body: some View {
        VStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.white)
                }

            Text(participant.name)
                .font(.caption2)
                .lineLimit(1)
        }
    }

    private var statusColor: Color {
        switch status {
        case .focused: .green
        case .distracted: .red
        case .outsideCircle: .red.opacity(0.6)
        case .disconnected: .gray
        }
    }
}
