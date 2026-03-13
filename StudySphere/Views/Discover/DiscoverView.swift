import SwiftUI
import VISOR

@LazyViewModel(DiscoverViewModel.self)
struct DiscoverView: View {

    var content: some View {
        Group {
            if viewModel.state.discoveredSessions.isEmpty {
                ContentUnavailableView(
                    "No Sessions Found",
                    systemImage: "wifi.slash",
                    description: Text("Looking for nearby study sessions..."))
            } else {
                List(viewModel.state.discoveredSessions) { session in
                    Button {
                        Task { await viewModel.handle(.joinSession(host: session)) }
                    } label: {
                        HStack {
                            Image(systemName: "person.2.circle.fill")
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(session.peerIDDisplayName)
                                    .font(.headline)
                                if let info = session.discoveryInfo?["sessionName"] {
                                    Text(info)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Discover")
        .task { await viewModel.handle(.startBrowsing) }
        .refreshable { await viewModel.handle(.refresh) }
    }
}
