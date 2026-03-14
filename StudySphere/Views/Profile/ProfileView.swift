import SwiftUI
import VISOR

@LazyViewModel(ProfileViewModel.self)
struct ProfileView: View {

    @State private var editedName: String = "Student"
    @State private var selectedAvatarSystemName: String = "person.circle.fill"

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

            // Edit profile
            Section("Edit Profile") {
                TextField("Name", text: $editedName)

                VStack(alignment: .leading, spacing: 8) {
                  Text("Avatar")
                    .font(.subheadline.bold())
                    

                  let avatars = ["person.circle.fill",
                                 "person.crop.circle.fill",
                                 "person.2.circle.fill",
                                 "person.crop.circle.fill.badge.checkmark",
                                 "person.circle",
                                 "person.crop.circle",
                                 "person.2.circle",
                                 "person.crop.circle.badge.checkmark"]
                    
                  ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                      ForEach(avatars, id: \.self) { symbol in
                        Button {
                          selectedAvatarSystemName = symbol
                          Task { await viewModel.handle(.updateAvatar(symbol)) }
                        } label: {
                          Image(systemName: symbol)
                            .font(.system(size: 32))
                            .foregroundStyle(symbol == selectedAvatarSystemName ? Color.accentColor : Color.primary)
                            .padding(8)
                            .background(
                              Circle()
                                .strokeBorder(symbol == selectedAvatarSystemName ? Color.accentColor : .clear, lineWidth: 2))
                        }
                        .buttonStyle(.plain)
                      }
                    }
                    .padding(.vertical, 4)
                  }
                }

                Button("Save Name") {
                  Task { await viewModel.handle(.updateName(editedName)) }
                }
                .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                          || editedName == (viewModel.state.profile?.name ?? "Student"))
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
        .task {
            await viewModel.handle(.loadProfile)
            editedName = viewModel.state.profile?.name ?? "Student"
            selectedAvatarSystemName = viewModel.state.profile?.avatarSystemName ?? "person.circle.fill"
        }
    }
}
