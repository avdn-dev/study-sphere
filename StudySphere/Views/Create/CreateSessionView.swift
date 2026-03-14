import SwiftUI
import VISOR

@LazyViewModel(CreateSessionViewModel.self)
struct CreateSessionView: View {
  @Environment(Router<AppScene>.self) private var router

    var content: some View {
        @Bindable var viewModel = viewModel

        return Form {
            Section("Session Details") {
                TextField("Session Name", text: $viewModel.state.sessionName)
            }

            Section("Focus Circle") {
                VStack(alignment: .leading) {
                    Text("Radius: \(Int(viewModel.state.radiusMeters))m")
                    Slider(value: $viewModel.state.radiusMeters, in: 1...20, step: 1)
                }

                VStack(alignment: .leading) {
                    let minutes = Int(viewModel.state.durationSeconds) / 60
                    Text("Duration: \(minutes > 0 ? "\(minutes) min" : "Unlimited")")
                    Slider(value: $viewModel.state.durationSeconds, in: 0...7200, step: 300)
                }

                Toggle("Require Stillness", isOn: $viewModel.state.requireStillness)
            }

            Section("App Blocking") {
                if viewModel.state.isScreenTimeAuthorized {
                    Button("Select Apps to Block") {
                        Task { await viewModel.handle(.showAppSelection) }
                    }
                } else {
                    Button("Authorize Screen Time") {
                        Task { await viewModel.handle(.requestScreenTimeAuth) }
                    }
                }
            }

            Section {
                Button {
                    Task { await viewModel.handle(.createSession) }
                } label: {
                    if viewModel.state.isCreating {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Create Session")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .disabled(viewModel.state.sessionName.isEmpty || viewModel.state.isCreating)
            }
        }
        .navigationTitle("Create Session")
        .toolbarTitleDisplayMode(.inlineLarge)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    router.dismissSheet()
                }
            }
        }
    }
}
