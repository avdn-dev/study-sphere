import MultipeerConnectivity
import VISOR

struct DiscoveredSession: Equatable, Identifiable {
    let peerID: MCPeerID
    var peerIDDisplayName: String { peerID.displayName }
    let discoveryInfo: [String: String]?

    var id: String { peerIDDisplayName }

    nonisolated static func == (lhs: DiscoveredSession, rhs: DiscoveredSession) -> Bool {
        lhs.peerID == rhs.peerID && lhs.discoveryInfo == rhs.discoveryInfo
    }
}

@Stubbable
@Spyable
protocol MultipeerService: AnyObject {
    var connectedPeers: [MCPeerID] { get }
    var discoveredSessions: [DiscoveredSession] { get }
    var isAdvertising: Bool { get }
    var isBrowsing: Bool { get }

    func startAdvertising(discoveryInfo: [String: String]?)
    func stopAdvertising()
    func startBrowsing()
    func stopBrowsing()
    func joinSession(host: DiscoveredSession) async
    func disconnect()
    func send(_ data: Data, mode: MCSessionSendDataMode) throws
    func send(_ data: Data, to peers: [MCPeerID], mode: MCSessionSendDataMode) throws
    func receivedDataStream() -> AsyncStream<(Data, MCPeerID)>
}

#if DEBUG
extension SpyMultipeerService.Call: Equatable {
    public static func == (lhs: SpyMultipeerService.Call, rhs: SpyMultipeerService.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
