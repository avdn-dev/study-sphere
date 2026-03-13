import Foundation
import MultipeerConnectivity
import VISOR
import OSLog

@Observable
final class LiveMultipeerService: MultipeerService {
    
    private static let roomHostingServiceType = "SSRoomHost"
    private static let roomPartyServiceType = "SSRoomParty"
    
    private let logger: Logger
    
    private(set) var state: MultipeerServiceState = .idle
    let peerID: MCPeerID
    private var _session: MCSession?
    
    var displayName: String {
        peerID.displayName
    }
    
    init(peerID: MCPeerID) {
        self.logger = Logger(subsystem: "study-sphere", category: "LiveMultipeerService")
        self.peerID = peerID
        self._roomBrowser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.roomPartyServiceType
        )
        self._participantBrowser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.roomHostingServiceType
        )
        self._delegate = _MCDelegate()
        _roomBrowser.delegate = _delegate
        _participantBrowser.delegate = _delegate
        self._delegate.parent = self
    }
    
    // MARK: - Room Discovery

    private let _roomBrowser: MCNearbyServiceBrowser
    private let _delegate: _MCDelegate
    
    private var _roomsInfo: [MCPeerID : RoomDiscoveryInfo] = [:] {
        didSet {
            guard discoveredRooms != nil else { return }
            guard _roomsInfo != oldValue else { return }
            discoveredRooms = .success(_roomsInfo)
        }
    }
    
    func startLookingForRooms() {
        _roomBrowser.startBrowsingForPeers()
        state = .lookingForRooms
    }
    
    func stopLookingForRooms() {
        _roomBrowser.stopBrowsingForPeers()
        discoveredRooms = nil
        state = .idle
    }
    
    private(set) var discoveredRooms: Result<[MCPeerID : RoomDiscoveryInfo], any Error>?
    
    // MARK: - Room Hosting
    
    private let _participantBrowser: MCNearbyServiceBrowser
    
    private var _participantsInfo: [MCPeerID : ParticipantDiscoveryInfo] = [:] {
        didSet {
            guard discoveredParticipants != nil else { return }
            guard _participantsInfo != oldValue else { return }
            discoveredParticipants = .success(_participantsInfo)
        }
    }

    func startLookingForParticipants() {
        _participantBrowser.startBrowsingForPeers()
        state = .lookingForParticipants
    }
    
    func stopLookingForParticipants() {
        _participantBrowser.stopBrowsingForPeers()
        discoveredParticipants = nil
        state = .idle
    }
    
    private(set) var discoveredParticipants: Result<[MCPeerID : ParticipantDiscoveryInfo], any Error>?
    
    // MARK: - Delegate
    
    private final class _MCDelegate: NSObject, MCNearbyServiceBrowserDelegate {
        unowned var parent: LiveMultipeerService!
        
        func browser(_ browser: MCNearbyServiceBrowser,
                     didNotStartBrowsingForPeers error: any Error) {
            switch browser {
            case self.parent._roomBrowser:
                parent.state = .idle
                parent._discoveredRooms = .failure(error)
                parent._roomsInfo.removeAll()
            case self.parent._participantBrowser:
                parent.state = .idle
                parent._discoveredRooms = .failure(error)
                parent._participantsInfo.removeAll()
            default:
                preconditionFailure()
            }
        }
        
        func browser(_ browser: MCNearbyServiceBrowser,
                     foundPeer peerID: MCPeerID,
                     withDiscoveryInfo info: [String : String]?) {
            switch browser {
            case self.parent._roomBrowser:
                guard let info = RoomDiscoveryInfo(peerID: peerID, discoveryInfo: info) else {
                    parent.logger.warning("Invalid info from room peer: \(peerID)")
                    return
                }
                guard !parent._roomsInfo.keys.contains(peerID) else {
                    parent.logger.warning("Duplicated room from peer: \(peerID)")
                    return
                }
                parent._roomsInfo[peerID] = info
            case self.parent._participantBrowser:
                guard let info = ParticipantDiscoveryInfo(peerID: peerID, discoveryInfo: info) else {
                    parent.logger.warning("Invalid info from participant peer: \(peerID)")
                    return
                }
                guard !parent._participantsInfo.keys.contains(peerID) else {
                    parent.logger.warning("Duplicated participant from peer: \(peerID)")
                    return
                }
                parent._participantsInfo[peerID] = info
            default:
                preconditionFailure()
            }
        }
        
        func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
            switch browser {
            case self.parent._roomBrowser:
                guard self.parent._roomsInfo.keys.contains(peerID) else {
                    parent.logger.warning("Room Peer to remove is missing: \(peerID)")
                    return
                }
                parent._roomsInfo.removeValue(forKey: peerID)
            case self.parent._participantBrowser:
                guard self.parent._participantsInfo.keys.contains(peerID) else {
                    parent.logger.warning("Room Participant to remove is missing: \(peerID)")
                    return
                }
                parent._participantsInfo.removeValue(forKey: peerID)
            default:
                preconditionFailure()
            }
        }
        
    }
    
}

//import MultipeerConnectivity
//import VISOR
//
//@Observable
//final class LiveMultipeerService: MultipeerService {
//
//    init(profileService: any ProfileService) {
//        self.profileService = profileService
//    }
//
//    // MARK: - State
//
//    var connectedPeers: [MCPeerID] = []
//    var discoveredSessions: [DiscoveredSession] = []
//    var isAdvertising = false
//    var isBrowsing = false
//
//    // MARK: - Host
//
//    func startAdvertising(discoveryInfo: [String: String]?) {
//        // TODO: Implement MCNearbyServiceAdvertiser
//    }
//
//    func stopAdvertising() {
//        // TODO: Stop advertising
//    }
//
//    // MARK: - Joiner
//
//    func startBrowsing() {
//        // TODO: Implement MCNearbyServiceBrowser
//    }
//
//    func stopBrowsing() {
//        // TODO: Stop browsing
//    }
//
//    func joinSession(host: DiscoveredSession) async {
//        // TODO: Send invitation to host peer
//    }
//
//    // MARK: - Session
//
//    func disconnect() {
//        // TODO: Disconnect from MCSession
//    }
//
//    // MARK: - Data
//
//    func send(_ data: Data, mode: MCSessionSendDataMode) throws {
//        // TODO: Send to all connected peers
//    }
//
//    func send(_ data: Data, to peers: [MCPeerID], mode: MCSessionSendDataMode) throws {
//        // TODO: Send to specific peers
//    }
//
//    func receivedDataStream() -> AsyncStream<(Data, MCPeerID)> {
//        // TODO: Return async stream of received data
//        AsyncStream { continuation in
//            continuation.finish()
//        }
//    }
//
//    // MARK: - Private
//
//    private let profileService: any ProfileService
//}
