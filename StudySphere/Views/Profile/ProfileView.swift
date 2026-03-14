import SwiftUI
import VISOR

private enum ProfileRoute: Hashable {
    case edit
}

@LazyViewModel(ProfileViewModel.self)
struct ProfileView: View {
    @State private var path = NavigationPath()
    @State private var showClearConfirmation = false

    var content: some View {
        NavigationStack(path: $path) {
          List {
            Section {
              VStack(spacing: 12) {
                profileAvatarView

                VStack(spacing: 4) {
                  Text(viewModel.state.profile?.name ?? "Student")
                    .font(.title.bold())
                  Text("Study Sphere Member")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 12)
              .listRowBackground(Color.clear)
            }

            Section("Study Stats") {
              HStack(spacing: 12) {
                ProfileStatCardView(icon: "clock.fill", value: formattedFocusTime(viewModel.totalFocusTime), label: "Focus Time")
                ProfileStatCardView(icon: "book.closed.fill", value: "\(viewModel.totalSessions)", label: "Sessions")
                ProfileStatCardView(icon: "target", value: String(format: "%.0f%%", viewModel.averageFocusScore * 100), label: "Focus Score")
              }
              .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
              .listRowBackground(Color.clear)
            }

            Section("Recent Sessions") {
              if viewModel.state.sessionHistory.isEmpty {
                ContentUnavailableView("No Sessions Yet", systemImage: "tray", description: Text("Completed study sessions will appear here."))
                  .listRowBackground(Color.clear)
              } else {
                ForEach(viewModel.state.sessionHistory.prefix(5)) { entry in
                  SessionHistoryRow(entry: entry)
                }
              }
            }

            if !viewModel.state.sessionHistory.isEmpty {
              Section {
                Button("Clear History", role: .destructive) {
                  showClearConfirmation = true
                }
              }
            }
        }
        .navigationTitle("Profile")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button {
              path.append(ProfileRoute.edit)
            } label: {
              Text("Edit")
            }
          }
        }
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
    }

    @ViewBuilder
    private var profileAvatarView: some View {
      if let image = viewModel.state.profileImage {
        Image(uiImage: image)
          .resizable()
          .scaledToFill()
          .frame(width: 80, height: 80)
          .clipShape(Circle())
      } else {
        Image(systemName: "person.circle.fill")
          .font(.system(size: 80))
          .foregroundStyle(.secondary)
      }
    }

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
