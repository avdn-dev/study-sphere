import SwiftUI
import VISOR

@LazyViewModel(ActiveSessionViewModel.self)
struct ActiveSessionView: View {
  @Environment(\.dismiss) private var dismiss

    @State private var isPulsing = false

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

            // Dimmed gradient overlay so text stays legible (lobby/reconnecting only)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.85),
                            Color.black.opacity(0.7),
                            Color.black.opacity(0.35),
                            Color.clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .ignoresSafeArea()
                .opacity(viewModel.state.activeSession?.isActive == true ? 0 : 1)

            // UI layer
            VStack(spacing: 16) {
                if viewModel.state.phase == .leaderReconnecting {
                    leaderReconnectingOverlay
                } else if viewModel.state.activeSession?.isActive == true {
                    liveSessionLayout
                } else {
                    waitingRoomLayout
                }
            }
            .padding(.bottom)
        }
        .onChange(of: viewModel.state.phase) { _, newPhase in
            if newPhase == .ended {
                dismiss()
            }
        }
        .toolbar {
          if viewModel.state.activeSession?.isActive == false {
            ToolbarItem(placement: .topBarLeading) {
              Button("End session", systemImage: "xmark") {
                Task {
                  await viewModel.handle(.endSession)
                  dismiss()
                }
              }
            }
          }
        }
    }

    // MARK: - Live session layout

    private var liveSessionLayout: some View {
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
                    if let time = viewModel.formattedElapsedTime {
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
                VStack(spacing: 8) {
                    Button("Leave Session") {
                        Task {
                            await viewModel.handle(.leaveSessionGracefully)
                            dismiss()
                        }
                    }
                    .glassButton()

                    Button("End Session", role: .destructive) {
                        Task {
                            await viewModel.handle(.endSession)
                            dismiss()
                        }
                    }
                    .glassButton()
                }
            } else {
                Button("Leave Session", role: .destructive) {
                    Task {
                        await viewModel.handle(.leaveSession)
                        dismiss()
                    }
                }
                .glassButton()
            }
        }
    }

    // MARK: - Reconnecting overlay

    private var leaderReconnectingOverlay: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            VStack(spacing: 8) {
                Text("Reconnecting…")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("The host left. Connecting to a new host…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }

            // Show elapsed time during reconnection
            if let time = viewModel.formattedElapsedTime {
                Text(time)
                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.5))
            }

            // Participant strip
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

            Button("Leave Session", role: .destructive) {
                Task {
                    await viewModel.handle(.leaveSession)
                    dismiss()
                }
            }
            .glassButton()
        }
    }

    // MARK: - Waiting room layout

    private var waitingRoomLayout: some View {
        VStack(spacing: 20) {
            lobbyHeaderCard
            participantsStrip
            sessionInfoCard

            Spacer()

            if viewModel.state.isHost {
                hostLobbyControls
            } else {
                participantLobbyControls
            }
        }
        .padding(.top, 8)
    }

    private var lobbyHeaderCard: some View {
        let statusText = viewModel.state.isHost ? "LOBBY • YOU'RE HOST" : "LOBBY • WAITING TO START"
        let descriptionText: String = {
            if viewModel.state.isHost {
                return "Start the circle when everyone’s in. Others join from Discover."
            } else {
                return "You’re in. Waiting for the host to start the focus circle."
            }
        }()

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 8, height: 8)
                    .scaleEffect(isPulsing ? 1.15 : 0.85)
                    .animation(
                        .easeInOut(duration: 1.2)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Text(statusText.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)
            }

            if let session = viewModel.state.activeSession {
                Text(session.settings.sessionName)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }

            Text(descriptionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .padding(.horizontal)
    }

    private var participantsStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CURRENT PARTICIPANTS (\(viewModel.state.participants.count))")
                .font(.caption.weight(.semibold))
                .tracking(1)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.state.participants) { participant in
                        ParticipantNodeView(
                            participant: participant,
                            status: viewModel.state.participantStatuses[participant.id] ?? participant.status
                        )
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.white.opacity(0.08))
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .padding(.horizontal)
    }

    private var sessionInfoCard: some View {
        let radiusText = "\(Int(activeRadiusMeters)) m"

        return HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "scope")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("FOCUS RADIUS")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(radiusText)
                        .font(.footnote.monospacedDigit())
                }
            }

            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.4))
        )
        .padding(.horizontal)
    }

    private var hostLobbyControls: some View {
        VStack(spacing: 8) {
            Button {
                Task { await viewModel.handle(.startSession) }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("Start Focus Circle")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
            }
            .glassButton()
            .controlSize(.large)

            Text("Participants join from Discover while this lobby is open.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.45))
        )
        .padding(.horizontal)
    }

    private var participantLobbyControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
                    .opacity(isPulsing ? 1 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.9)
                            .repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                Text("Waiting for host to start…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Button("Leave Lobby", role: .destructive) {
                Task {
                    await viewModel.handle(.leaveSession)
                    dismiss()
                }
            }
            .glassButton()
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.45))
        )
        .padding(.horizontal)
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

        if let imageData = participant.avatarImageData,
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().stroke(color, lineWidth: 2))
                .shadow(color: color.opacity(0.6), radius: 6)
        } else {
            Image(systemName: participant.avatarSystemName)
                .font(.system(size: 32))
                .foregroundStyle(color)
                .shadow(color: color.opacity(0.6), radius: 6)
        }
    }

    private func avatarColor(for status: ParticipantStatus) -> Color {
        switch status {
        case .focused: Color(red: 0.15, green: 0.45, blue: 0.75)
        case .distracted: Color(red: 0.75, green: 0.15, blue: 0.20)
        case .outsideCircle: Color(red: 0.75, green: 0.15, blue: 0.20).opacity(0.6)
        case .disconnected: .gray
        case .reconnecting: .gray.opacity(0.6)
        }
    }
}
