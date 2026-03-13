import SwiftUI
import VISOR

@LazyViewModel(ProfileViewModel.self)
struct ProfileView: View {

    var content: some View {
        List {
            // Profile card
            Section {
                HStack(spacing: 16) {
                    Image(systemName: viewModel.state.profile?.avatarSystemName ?? "person.circle.fill")
                        .font(.system(size: 60))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(viewModel.state.profile?.name ?? "Student")
                            .font(.title2.bold())
                        Text("Study Sphere Member")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            // Stats
            Section("Statistics") {
                LabeledContent("Total Sessions", value: "\(viewModel.totalSessions)")
                LabeledContent("Total Focus Time") {
                    let hours = Int(viewModel.totalFocusTime) / 3600
                    let minutes = (Int(viewModel.totalFocusTime) % 3600) / 60
                    Text("\(hours)h \(minutes)m")
                }
                LabeledContent("Average Focus Score") {
                    Text(String(format: "%.0f%%", viewModel.averageFocusScore * 100))
                }
            }

            // Session history
            Section("Session History") {
                if viewModel.state.sessionHistory.isEmpty {
                    Text("No sessions yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(viewModel.state.sessionHistory) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.sessionName)
                                .font(.headline)
                            HStack {
                                Text(entry.date, style: .date)
                                Spacer()
                                Text(String(format: "%.0f%%", entry.focusScore * 100))
                                    .foregroundStyle(entry.focusScore > 0.7 ? .green : .orange)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            // Actions
            Section {
                Button("Clear History", role: .destructive) {
                    Task { await viewModel.handle(.clearHistory) }
                }
            }
        }
        .navigationTitle("Profile")
        .task { await viewModel.handle(.loadProfile) }
    }
}
