import MultipeerConnectivity
import VISOR

@Observable
final class LiveMultipeerService: MultipeerService {

    init(profileService: any ProfileService) {
        self.profileService = profileService
    }

    // MARK: - State

    var connectedPeers: [MCPeerID] = []
    var discoveredSessions: [DiscoveredSession] = []
    var isAdvertising = false
    var isBrowsing = false

    // MARK: - Host

    func startAdvertising(discoveryInfo: [String: String]?) {
        // TODO: Implement MCNearbyServiceAdvertiser
    }

    func stopAdvertising() {
        // TODO: Stop advertising
    }

    // MARK: - Joiner

    func startBrowsing() {
        // TODO: Implement MCNearbyServiceBrowser
    }

    func stopBrowsing() {
        // TODO: Stop browsing
    }

    func joinSession(host: DiscoveredSession) async {
        // TODO: Send invitation to host peer
    }

    // MARK: - Session

    func disconnect() {
        // TODO: Disconnect from MCSession
    }

    // MARK: - Data

    func send(_ data: Data, mode: MCSessionSendDataMode) throws {
        // TODO: Send to all connected peers
    }

    func send(_ data: Data, to peers: [MCPeerID], mode: MCSessionSendDataMode) throws {
        // TODO: Send to specific peers
    }

    func receivedDataStream() -> AsyncStream<(Data, MCPeerID)> {
        // TODO: Return async stream of received data
        AsyncStream { continuation in
            continuation.finish()
        }
    }

    // MARK: - Private

    private let profileService: any ProfileService
}
