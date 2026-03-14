import SwiftUI
import VISOR

@LazyViewModel(DiscoverViewModel.self)
struct DiscoverView: View {

    @Environment(Router<AppScene>.self) private var router

    var content: some View {
        Group {
            if viewModel.state.discoveredRooms.isEmpty {
                ContentUnavailableView {
                    Label(
                        viewModel.state.isSearching ? "Searching..." : "No Sessions Found",
                        systemImage: viewModel.state.isSearching
                            ? "antenna.radiowaves.left.and.right"
                            : "magnifyingglass"
                    )
                } description: {
                    Text(
                        viewModel.state.isSearching
                            ? "Looking for nearby study sessions"
                            : "No nearby sessions are available right now"
                    )
                }
            } else {
                List(viewModel.state.discoveredRooms, id: \.peerID) { room in
                    Button {
                        Task { await viewModel.handle(.joinSession(room: room)) }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(room.roomName)
                                .font(.headline)
                            Text(room.displayName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .disabled(viewModel.state.isJoining)
                }
            }
        }
        .overlay {
            if viewModel.state.isJoining {
                ProgressView("Joining...")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .navigationTitle("Join Session")
        .toolbarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    Task { await viewModel.handle(.stopBrowsing) }
                    router.dismissSheet()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await viewModel.handle(.refresh) }
                }
                .disabled(viewModel.state.isJoining)
            }
        }
        .task {
            await viewModel.handle(.startBrowsing)
        }
        .onDisappear {
            Task { await viewModel.handle(.stopBrowsing) }
        }
    }
}
