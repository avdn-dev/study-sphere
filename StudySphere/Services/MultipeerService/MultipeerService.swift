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
    
    init(peerID: MCPeerID, roomName: String) {
        self.peerID = peerID
        self.roomName = roomName
    }
    
    var discoveryInfo: [String : String] {
        [
            Keys.roomName: roomName
        ]
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
    
    var discoveryInfo: [String : String] {
        [
            Keys.participantName: participantName
        ]
    }
    
}

struct RoomConfiguration {
    var displayName: String
}

@Stubbable
@Spyable
protocol MultipeerService: AnyObject {
    
    @StubbableDefault(MultipeerServiceState.idle)
    var state: MultipeerServiceState { get }
    var displayName: String { get }
    
    // Room Browsing
    var discoveredRooms: Result<[MCPeerID : RoomDiscoveryInfo], any Error>? { get }
    var isLookingForRooms: Bool { get }
    func startLookingForRooms()
    func stopLookingForRooms()
    
    // Joining A Room
    func joinRoom(with info: RoomDiscoveryInfo) async throws -> Bool
    
    // Room Hosting
    var discoveredParticipants: Result<[MCPeerID : ParticipantDiscoveryInfo], any Error>? { get }
    var isLookingForParticipants: Bool { get }
    func startLookingForParticipants() throws
    func stopLookingForParticipants()
    
    var currentStudySession: StudySession? { get }
    func setCurrentSession(_ session: StudySession) throws
    
    // Sending Messages
    #warning("TODO: Decide on what messages to send")
    var messages: AsyncStream<Void> { get }
    func send(message: Void) throws
    
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
    
    var messages: AsyncStream<Void> {
        preconditionFailure("Not implemented")
    }
    
}

enum MultipeerServiceError: Swift.Error {
    case missingRoom
    case alreadyInRoom
    case notLookingForRooms
    case roomInfoInvalid
    case alreadyJoiningRoom
    case failedToJoinRoom
}

enum MultipeerServiceState {
    case idle
    case lookingForRooms
    case lookingForParticipants
    case joiningRoom
    case connectedAsHost
    case connectedAsParticipant
}
