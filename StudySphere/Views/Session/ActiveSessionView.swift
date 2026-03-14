import SwiftUI
import VISOR

@LazyViewModel(ActiveSessionViewModel.self)
struct ActiveSessionView: View {
  @Environment(\.dismiss) private var dismiss

    private var activeRadiusMeters: Double {
        viewModel.state.activeSession?.settings.radiusMeters ?? 5.0
    }

    var content: some View {
        ZStack {
            Color(red: 0.04, green: 0.09, blue: 0.16)
                .ignoresSafeArea()

            // Full-screen Metal view — blob never clips
            MetalMetaballView(
                participants: viewModel.state.participants,
                positions: viewModel.state.estimatedPositions,
                statuses: viewModel.state.participantStatuses,
                radiusMeters: activeRadiusMeters
            )
            .ignoresSafeArea()

            // UI layer
            VStack(spacing: 12) {
                // Avatar zone: 1:1 square at screen width, pinned to top
                ZStack {
                    GeometryReader { geo in
                        let side = geo.size.width
                        ForEach(viewModel.state.participants) { participant in
                            let status = viewModel.state.participantStatuses[participant.id] ?? participant.status
                            let pos = avatarPosition(for: participant, viewSize: side)
                            avatarView(participant: participant, status: status)
                                .position(pos)
                        }
                    }
                    .aspectRatio(1, contentMode: .fit)

                    // Timer centered on the field
                    VStack(spacing: 4) {
                        if let time = viewModel.formattedRemainingTime {
                            Text(time)
                                .font(.system(size: 48, weight: .bold, design: .monospaced))
                                .foregroundStyle(viewModel.state.isLocalDeviceDistracted ? .red : .white)
                                .shadow(color: .black.opacity(0.6), radius: 4)
                        }
                        if let session = viewModel.state.activeSession {
                            Text(session.settings.sessionName)
                                .font(.title2)
                                .foregroundStyle(.white.opacity(0.7))
                                .shadow(color: .black.opacity(0.6), radius: 4)
                        }
                    }
                }

                // Participant list
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(viewModel.state.participants) { participant in
                            ParticipantNodeView(
                                participant: participant,
                                status: viewModel.state.participantStatuses[participant.id] ?? participant.status
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer()

                // Controls
                if viewModel.state.isHost {
                    if viewModel.state.activeSession?.isActive == true {
                        Button("End Session", role: .destructive) {
                          Task {
                            await viewModel.handle(.endSession)
                            dismiss()
                          }
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
                      Task {
                        await viewModel.handle(.leaveSession)
                        dismiss()
                      }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.bottom)
        }
        .toolbar {
          if viewModel.state.activeSession?.isActive == false {
            ToolbarItem(placement: .topBarLeading) {
              Button("End session", systemImage: "xmark") {
                dismiss()
              }
            }
          }
        }
    }

    // MARK: - Coordinate Mapping

    /// Maps world-space meters to the 1:1 avatar square (side = screen width).
    /// Uses the same `worldExtent = radiusMeters * 3.0` as the Metal shader.
    private func avatarPosition(for participant: Participant, viewSize: CGFloat) -> CGPoint {
        let worldExtent = activeRadiusMeters * 3.0
        let key = participant.peerIDData.base64EncodedString()

        let worldX: Double
        let worldY: Double
        if let pos = viewModel.state.estimatedPositions[key] {
            worldX = pos.x
            worldY = pos.y
        } else if let pos = participant.position {
            worldX = pos.x
            worldY = pos.y
        } else {
            worldX = 0
            worldY = 0
        }

        let x = (worldX / worldExtent + 0.5) * Double(viewSize)
        let y = (worldY / worldExtent + 0.5) * Double(viewSize)
        return CGPoint(x: x, y: y)
    }

    // MARK: - Avatar

    @ViewBuilder
    private func avatarView(participant: Participant, status: ParticipantStatus) -> some View {
        let color = avatarColor(for: status)

        Image(systemName: participant.avatarSystemName)
            .font(.system(size: 32))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 6)
    }

    private func avatarColor(for status: ParticipantStatus) -> Color {
        switch status {
        case .focused: Color(red: 0.15, green: 0.45, blue: 0.75)
        case .distracted: Color(red: 0.75, green: 0.15, blue: 0.20)
        case .outsideCircle: Color(red: 0.75, green: 0.15, blue: 0.20).opacity(0.6)
        case .disconnected: .gray
        }
    }
}
