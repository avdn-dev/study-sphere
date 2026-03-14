import SwiftUI

struct ParticipantNodeView: View {
    let participant: Participant
    let status: ParticipantStatus

    var body: some View {
        VStack(spacing: 4) {
            if let imageData = participant.avatarImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(statusColor, lineWidth: 2))
            } else {
                Circle()
                    .fill(statusColor)
                    .frame(width: 44, height: 44)
                    .overlay {
                        Image(systemName: "person.crop.circle.fill")
                            .foregroundStyle(.white)
                    }
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
