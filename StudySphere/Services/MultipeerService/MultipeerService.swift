import MultipeerConnectivity
import VISOR

struct RoomDiscoveryInfo: Equatable {
    
    enum Keys {
        static let roomName = "name"
    }
    
    let peerID: MCPeerID
    var displayName: String { peerID.displayName }
    
    let roomName: String
    
    init?(peerID: MCPeerID, discoveryInfo: [String : String]?) {
        guard
            let info = discoveryInfo,
            let roomName = info[Keys.roomName]
        else {
            return nil
        }
        self.peerID = peerID
        self.roomName = roomName
    }
    
}

struct ParticipantDiscoveryInfo: Equatable {
    
    enum Keys {
        static let participantName = "name"
    }
    
    let peerID: MCPeerID
    var displayName: String { peerID.displayName }
    
    let participantName: String
    
    init?(peerID: MCPeerID, discoveryInfo: [String : String]?) {
        guard
            let info = discoveryInfo,
            let participantName = info[Keys.participantName]
        else {
            return nil
        }
        self.peerID = peerID
        self.participantName = participantName
    }
    
}

//@Stubbable
//@Spyable
protocol MultipeerService: AnyObject, Observable {
    var state: MultipeerServiceState { get }
    var displayName: String { get }
    
    // Room Browsing
    var discoveredRooms: Result<[MCPeerID : RoomDiscoveryInfo], any Error>? { get }
    var isLookingForRooms: Bool { get }
    func startLookingForRooms()
    func stopLookingForRooms()
    
    // Room Hosting
    var discoveredParticipants: Result<[MCPeerID : ParticipantDiscoveryInfo], any Error>? { get }
    var isLookingForParticipants: Bool { get }
    func startLookingForParticipants()
    func stopLookingForParticipants()
}

extension MultipeerService {
    
    var isHost: Bool {
        state == .connectedAsHost || state == .lookingForParticipants
    }
    
    var isParticipant: Bool {
        state == .connectedAsParticipant || state == .lookingForRooms
    }
    
    var isLookingForRooms: Bool {
        state == .lookingForRooms
    }
    
    var isLookingForParticipants: Bool {
        state == .lookingForParticipants
    }
    
}

enum MultipeerServiceError: Swift.Error {
    
}

enum MultipeerServiceState {
    case idle
    case lookingForRooms
    case lookingForParticipants
    case connectedAsHost
    case connectedAsParticipant
}
