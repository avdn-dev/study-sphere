import SwiftUI
import VISOR

@LazyViewModel(ActiveSessionViewModel.self)
struct ActiveSessionView: View {

    var content: some View {
        VStack(spacing: 20) {
            // Timer
            if let time = viewModel.formattedRemainingTime {
                Text(time)
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundStyle(viewModel.state.isLocalDeviceDistracted ? .red : .primary)
            }

            // Session name
            if let session = viewModel.state.activeSession {
                Text(session.settings.sessionName)
                    .font(.title2)
            }

            // Metaball visualization
            MetaballView(
                participants: viewModel.state.participants,
                positions: viewModel.state.estimatedPositions,
                statuses: viewModel.state.participantStatuses,
                radiusMeters: viewModel.state.activeSession?.settings.radiusMeters ?? 5.0)
                .frame(height: 300)

            // Participant list
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(viewModel.state.participants) { participant in
                        ParticipantNodeView(
                            participant: participant,
                            status: viewModel.state.participantStatuses[participant.id] ?? participant.status)
                    }
                }
                .padding(.horizontal)
            }

            Spacer()

            // Controls
            if viewModel.state.isHost {
                if viewModel.state.activeSession?.isActive == true {
                    Button("End Session", role: .destructive) {
                        Task { await viewModel.handle(.endSession) }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Start Session") {
                        Task { await viewModel.handle(.startSession) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Button("Leave Session", role: .destructive) {
                    Task { await viewModel.handle(.leaveSession) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}
