import SwiftUI
import VISOR

private enum ProfileRoute: Hashable {
    case edit
}

@LazyViewModel(ProfileViewModel.self)
struct ProfileView: View {
    @State private var path = NavigationPath()
    @State private var showClearConfirmation = false
    @State private var isPulsing = false

    var content: some View {
        NavigationStack(path: $path) {
            ZStack {
                Color(red: 0.04, green: 0.09, blue: 0.16)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        Color.background.opacity(0.2),
                        Color.clear,
                        Color.background.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        avatarHeaderCard
                        statsRow
                        recentSessionsCard
                        if !viewModel.state.sessionHistory.isEmpty {
                            clearHistoryButton
                        }
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(
                Color(red: 0.04, green: 0.09, blue: 0.16).opacity(0.9),
                for: .navigationBar
            )
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Edit") {
                        path.append(ProfileRoute.edit)
                    }
                    .foregroundStyle(Color.accentPrimary)
                }
            }
            .confirmationDialog("Clear all session history?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) {
                    Task { await viewModel.handle(.clearHistory) }
                }
<<<<<<< Updated upstream
                .glassButton()
                .confirmationDialog("Clear all session history?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                  Button("Clear History", role: .destructive) {
                    Task { await viewModel.handle(.clearHistory) }
                  }
                } message: {
                    Text("This action cannot be undone.")
                }
              }
||||||| Stash base
              }
=======
            } message: {
                Text("This action cannot be undone.")
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                if route == .edit {
                    EditProfileView(onDismiss: { path.removeLast() })
                }
            }
            .task {
                await viewModel.handle(.loadProfile)
                isPulsing = true
>>>>>>> Stashed changes
            }
        }
    }

    // MARK: - Avatar Header Card

    private var avatarHeaderCard: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.accentPrimary.opacity(isPulsing ? 0.28 : 0.08), lineWidth: 2)
                    .frame(width: 90, height: 90)
                    .scaleEffect(isPulsing ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 2.4).repeatForever(autoreverses: true),
                        value: isPulsing
                    )

                profileAvatarView
            }

            VStack(spacing: 4) {
                Text(viewModel.state.profile?.name ?? "Student")
                    .font(.title2.bold())
                    .foregroundStyle(Color.labelPrimary)

                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.accentPrimary)
                        .frame(width: 6, height: 6)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .animation(
                            .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                            value: isPulsing
                        )
                    Text("Study Sphere Member")
                        .font(.subheadline)
                        .foregroundStyle(Color.labelSecondary)
                }
            }
        }
<<<<<<< Updated upstream
        .navigationDestination(for: ProfileRoute.self) { route in
          if route == .edit {
            EditProfileView(onDismiss: { path.removeLast() })
          }
        }
        .task {
          await viewModel.handle(.loadProfile)
        }
      }
||||||| Stash base
        .confirmationDialog("Clear all session history?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
          Button("Clear History", role: .destructive) {
            Task { await viewModel.handle(.clearHistory) }
          }
        } message: {
            Text("This action cannot be undone.")
        }
        .navigationDestination(for: ProfileRoute.self) { route in
          if route == .edit {
            EditProfileView(onDismiss: { path.removeLast() })
          }
        }
        .task {
          await viewModel.handle(.loadProfile)
        }
      }
=======
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .padding(.horizontal)
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        HStack(spacing: 10) {
            statCard(icon: "clock.fill",       value: formattedFocusTime(viewModel.totalFocusTime),                 label: "Focus Time")
            statCard(icon: "book.closed.fill", value: "\(viewModel.totalSessions)",                                label: "Sessions")
            statCard(icon: "target",           value: String(format: "%.0f%%", viewModel.averageFocusScore * 100), label: "Focus Score")
        }
        .padding(.horizontal)
>>>>>>> Stashed changes
    }

    @ViewBuilder
    private func statCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.accentPrimary)
            Text(value)
                .font(.system(.title3, design: .monospaced).bold())
                .foregroundStyle(Color.labelPrimary)
            Text(label.uppercased())
                .font(.system(size: 9).weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(Color.labelTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.4))
        )
    }

    // MARK: - Recent Sessions Card

    private var recentSessionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Text("RECENT SESSIONS")
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(Color.labelSecondary)
                Spacer()
                if !viewModel.state.sessionHistory.isEmpty {
                    Text("\(min(viewModel.state.sessionHistory.count, 5)) of \(viewModel.state.sessionHistory.count)")
                        .font(.caption)
                        .foregroundStyle(Color.labelTertiary)
                }
            }

            if viewModel.state.sessionHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundStyle(Color.labelTertiary)
                    Text("No Sessions Yet")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.labelSecondary)
                    Text("Completed study sessions will appear here.")
                        .font(.caption)
                        .foregroundStyle(Color.labelTertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                VStack(spacing: 1) {
                    ForEach(viewModel.state.sessionHistory.prefix(5)) { entry in
                        SessionHistoryRow(entry: entry)
                            .padding(.vertical, 4)
                        if entry.id != viewModel.state.sessionHistory.prefix(5).last?.id {
                            Divider()
                                .background(Color.white.opacity(0.06))
                        }
                    }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.35))
        )
        .padding(.horizontal)
    }

    // MARK: - Clear History Button

    private var clearHistoryButton: some View {
        Button {
            showClearConfirmation = true
        } label: {
            Text("Clear History")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.35))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Avatar

    @ViewBuilder
    private var profileAvatarView: some View {
        if let image = viewModel.state.profileImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        LinearGradient(
                            colors: [Color.accentPrimary, Color.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                )
                .shadow(color: Color.accentPrimary.opacity(0.4), radius: 8)
        } else {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.secondary)
                .shadow(color: Color.accentPrimary.opacity(0.4), radius: 8)
        }
    }

    // MARK: - Helpers

    private func formattedFocusTime(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "\(total)s"
        }
    }
}
