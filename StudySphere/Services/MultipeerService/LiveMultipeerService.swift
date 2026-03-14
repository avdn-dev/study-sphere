import Foundation
import MultipeerConnectivity
import VISOR
import OSLog

@Observable
final class LiveMultipeerService: MultipeerService {

    private static let roomHostingServiceType = "SSRoomHost"
    private static let roomPartyServiceType = "SSRoomParty"
    static let timeout: TimeInterval = 30.0

    private static let decoder = JSONDecoder()
    private static let encoder = JSONEncoder()

    private let logger: Logger

    private(set) var state: MultipeerServiceState = .idle
    let peerID: MCPeerID
    private var _session: MCSession?

    var displayName: String {
        peerID.displayName
    }

    // MARK: - Event Callbacks

    @ObservationIgnored
    var messageHandler: ((_ peerID: MCPeerID, _ message: SessionMessage) -> Void)?
    @ObservationIgnored
    var peerConnectedHandler: ((_ peerID: MCPeerID) -> Void)?
    @ObservationIgnored
    var peerDisconnectedHandler: ((_ peerID: MCPeerID) -> Void)?

    var connectedPeers: [MCPeerID] {
        _session?.connectedPeers ?? []
    }

    init(peerID: MCPeerID) {
        self.logger = Logger(subsystem: "study-sphere", category: "LiveMultipeerService")
        self.peerID = peerID
        self._roomBrowser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.roomHostingServiceType
        )
        self._participantBrowser = MCNearbyServiceBrowser(
            peer: peerID,
            serviceType: Self.roomPartyServiceType
        )
        self._delegate = _MCDelegate()
        _roomBrowser.delegate = _delegate
        _participantBrowser.delegate = _delegate
        self._delegate.parent = self
    }

    // MARK: - Room Discovery

    private let _roomBrowser: MCNearbyServiceBrowser
    private var _participantAdvertiser: MCNearbyServiceAdvertiser?
    private let _delegate: _MCDelegate

    private(set) var discoveredRooms: Result<[MCPeerID : RoomDiscoveryInfo], any Error>?

    private var _roomsInfo: [MCPeerID : RoomDiscoveryInfo] = [:] {
        didSet {
            guard _roomsInfo != oldValue else { return }
            discoveredRooms = .success(_roomsInfo)
            switch discoveredRooms {
            case .success:
                discoveredRooms = .success(_roomsInfo)
            case .failure, nil:
                return
            }
        }
    }

    func startLookingForRooms(using name: String) throws {
        _roomBrowser.startBrowsingForPeers()
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: ParticipantDiscoveryInfo(
                peerID: peerID,
                participantName: name
            ).discoveryInfo,
            serviceType: Self.roomPartyServiceType)
        _participantAdvertiser = advertiser
        advertiser.startAdvertisingPeer()
        discoveredRooms = .success([:])
        logger.trace("\(#function): Started looking for rooms using name \(name)")
        state = .lookingForRooms
    }

    func stopLookingForRooms() {
        _stopLookingForRooms(with: nil)
    }

    func _stopLookingForRooms(with error: (any Error)?) {
        logger.trace("\(#function): Stopped looking for rooms with error \(error.debugDescription)")
        _roomBrowser.stopBrowsingForPeers()
        _participantAdvertiser?.stopAdvertisingPeer()
        if let error = error {
            discoveredRooms = .failure(error)
        } else {
            discoveredRooms = nil
        }
        state = .idle
        _roomsInfo = [:]
    }

    // MARK: - Joining A Room

    private var _roomJoinContinuation: CheckedContinuation<Bool, any Error>?
    private var _roomJoinPeerID: MCPeerID?

    func joinRoom(with info: RoomDiscoveryInfo, joinRequest: JoinRequest) async throws -> Bool {
        switch self.discoveredRooms {
        case .success(let rooms):
            guard rooms.keys.contains(info.peerID) else {
                throw MultipeerServiceError.roomInfoInvalid
            }
            guard _roomJoinContinuation == nil else {
                logger.error("Already joining a room")
                throw MultipeerServiceError.alreadyJoiningRoom
            }
            let session = MCSession(peer: peerID)
            session.delegate = _delegate // Bug fix: set delegate
            _session = session
            _roomJoinPeerID = info.peerID
            state = .joiningRoom
            let joinRequestData = try Self.encoder.encode(joinRequest)
            let result = try await withCheckedThrowingContinuation { continuation in
                logger.trace("Sending join request to room peer: \(info.peerID)")
                _roomBrowser.invitePeer(
                    info.peerID,
                    to: session,
                    withContext: joinRequestData,
                    timeout: Self.timeout)
                _roomJoinContinuation = continuation
            }
            guard result else {
                logger.trace("Join request to room peer \(info.peerID) rejected")
                _session = nil
                state = .idle
                return false
            }
            logger.trace("Join request to room peer \(info.peerID) accepted")
            state = .connectedAsParticipant
            return true
        case .failure(let failure):
            throw failure
        case .none:
            throw MultipeerServiceError.notLookingForRooms
        }
    }

    @ObservationIgnored
    var joinRequestHandler: ((MCPeerID, JoinRequest) async throws -> Bool)?

    private var _participantPendingJoins: [MCPeerID : CheckedContinuation<Void, any Error>] = [:]

    // MARK: - Room Hosting

    private let _participantBrowser: MCNearbyServiceBrowser
    private var _roomAdvertiser: MCNearbyServiceAdvertiser?
    private var _currentStudySession: StudySession?

    private(set) var discoveredParticipants: Result<[MCPeerID : ParticipantDiscoveryInfo], any Error>?

    private var _participantsInfo: [MCPeerID : ParticipantDiscoveryInfo] = [:] {
        didSet {
            guard _participantsInfo != oldValue else { return }
            switch discoveredParticipants {
            case .success:
                discoveredParticipants = .success(_participantsInfo)
            case .failure, nil:
                return
            }
        }
    }

    func startLookingForParticipants() throws {
        guard let roomAdvertiser = self._roomAdvertiser else {
            throw MultipeerServiceError.missingRoom
        }
        _participantBrowser.startBrowsingForPeers()
        roomAdvertiser.startAdvertisingPeer()
        roomAdvertiser.delegate = _delegate
        state = .lookingForParticipants
        discoveredParticipants = .success([:])
    }

    func stopLookingForParticipants() {
        _stopLookingForParticipants(with: nil)
    }

    private func _stopLookingForParticipants(with error: (any Error)?) {
        _participantBrowser.stopBrowsingForPeers()
        _roomAdvertiser?.stopAdvertisingPeer()
        discoveredParticipants = nil
        _participantsInfo.removeAll()
    }

    var currentStudySession: StudySession? {
        get {
            _currentStudySession
        }
    }

    func setCurrentSession(_ session: StudySession) throws {
        guard self._currentStudySession != session else { return }
        switch self.state {
        case .lookingForParticipants:
            logger.warning("Don't change the room while it is looking for participants")
            stopLookingForParticipants()
        case .connectedAsHost:
            logger.error("Close the room first before changing it")
            #warning("TODO: Handle host")
            throw MultipeerServiceError.invalidState
        case .lookingForRooms:
            logger.warning("Don't change the room while looking for a room.")
            stopLookingForRooms()
        case .connectedAsParticipant:
            logger.error("Disconnect from the room first before creating a new one")
            #warning("TODO: Handle participant")
            throw MultipeerServiceError.invalidState
        case .joiningRoom:
            logger.error("Cannot create new room while joining one")
            #warning("TODO: Handle joining room")
            throw MultipeerServiceError.invalidState
        case .idle:
            break
        }
        self._currentStudySession = session
        let newSession = MCSession(peer: peerID)
        newSession.delegate = _delegate // Bug fix: set delegate
        self._session = newSession
        self._roomAdvertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: RoomDiscoveryInfo(
                peerID: peerID,
                roomName: session.settings.sessionName
            ).discoveryInfo,
            serviceType: Self.roomHostingServiceType
        )
        logger.trace("\(#function): Session updated successfully")
    }

    // MARK: - Connection Management

    func disconnect() {
        _session?.disconnect()
        _session = nil
        _currentStudySession = nil
        state = .idle

        messageHandler = nil
        peerConnectedHandler = nil
        peerDisconnectedHandler = nil
    }

    // MARK: - Sending Messages

    func send(_ message: SessionMessage, to peers: [MCPeerID], reliable: Bool) throws {
        guard let session = _session else {
            throw MultipeerServiceError.invalidState
        }
        let data = try Self.encoder.encode(message)
        try session.send(data, toPeers: peers, with: reliable ? .reliable : .unreliable)
    }

    func sendToAll(_ message: SessionMessage, reliable: Bool) throws {
        guard let session = _session else {
            throw MultipeerServiceError.invalidState
        }
        let peers = session.connectedPeers
        guard !peers.isEmpty else { return }
        let data = try Self.encoder.encode(message)
        try session.send(data, toPeers: peers, with: reliable ? .reliable : .unreliable)
    }

    // MARK: - Delegate

    private final class _MCDelegate: NSObject,
        MCNearbyServiceBrowserDelegate,
        MCNearbyServiceAdvertiserDelegate,
        MCSessionDelegate
    {
        unowned var parent: LiveMultipeerService!

        // Browser Delegate

        func browser(_ browser: MCNearbyServiceBrowser,
                     didNotStartBrowsingForPeers error: any Error) {
            switch browser {
            case self.parent._roomBrowser:
                parent._stopLookingForRooms(with: error)
            case self.parent._participantBrowser:
                parent._stopLookingForParticipants(with: error)
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
                parent._roomsInfo[peerID] = info
            case self.parent._participantBrowser:
                guard let info = ParticipantDiscoveryInfo(peerID: peerID, discoveryInfo: info) else {
                    parent.logger.warning("Invalid info from participant peer: \(peerID)")
                    return
                }
                parent._participantsInfo[peerID] = info
            default:
                preconditionFailure()
            }
        }

        func browser(_ browser: MCNearbyServiceBrowser,
                     lostPeer peerID: MCPeerID) {
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

        // Advertiser Delegate

        func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                        didNotStartAdvertisingPeer error: any Error) {
            switch advertiser {
            case self.parent._roomAdvertiser:
                parent.logger.error("Failed to advertise room: \(error)")
            default:
                parent.logger.error("Unknown advertiser failed: \(error)")
            }
        }

        func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                        didReceiveInvitationFromPeer peerID: MCPeerID,
                        withContext context: Data?,
                        invitationHandler: @escaping (Bool, MCSession?) -> Void) {
            switch advertiser {
            case self.parent._roomAdvertiser:
                switch self.parent.state {
                // Bug fix: accept invitations in both lookingForParticipants and connectedAsHost
                case .lookingForParticipants, .connectedAsHost:
                    parent.logger.trace("Received participant invitation from: \(peerID)")
                    guard let context = context else {
                        parent.logger.warning("\(peerID) Missing context, ignoring")
                        invitationHandler(false, nil)
                        return
                    }
                    let contextData = context
                    let mcPeerID = peerID // Capture the MC framework peerID before entering the Task
                    Task { @MainActor [parent] in
                        // Read joinRequestHandler on MainActor to avoid a data race —
                        // this delegate method fires on MC's background queue.
                        guard let joinRequestHandler = parent?.joinRequestHandler else {
                            parent?.logger.error("Received invitation but no handler set")
                            invitationHandler(false, nil)
                            return
                        }
                        let joinRequest: JoinRequest
                        do {
                            joinRequest = try LiveMultipeerService.decoder.decode(JoinRequest.self, from: contextData)
                        } catch {
                            parent?.logger.warning("join request is malformed with error: \(error), ignoring")
                            invitationHandler(false, nil)
                            return
                        }
                        do {
                            guard try await joinRequestHandler(mcPeerID, joinRequest) else {
                                parent?.logger.trace("Join request for \(mcPeerID) rejected")
                                invitationHandler(false, nil)
                                return
                            }
                            parent?.logger.trace("Join request for \(mcPeerID) accepted")
                            invitationHandler(true, parent?._session)
                        } catch {
                            parent?.logger.warning("Join request handler for \(mcPeerID) threw an error: \(error)")
                            invitationHandler(false, nil)
                        }
                    }
                default:
                    parent.logger.error("Invalid state for receiving an invitation: \(self.parent.state)")
                    invitationHandler(false, nil)
                }
            default:
                parent.logger.warning("Unexpected advertiser received invitation")
                invitationHandler(false, nil)
            }
        }

        // Session Delegate

        func session(_ session: MCSession,
                     peer peerID: MCPeerID,
                     didChange state: MCSessionState) {
            guard session === self.parent._session else {
                parent.logger.warning("Session state change for unknown session")
                return
            }

            switch parent.state {
            case .joiningRoom:
                guard let continuation = parent._roomJoinContinuation else {
                    parent.logger.error("\(#function): Missing room join continuation")
                    return
                }
                guard let roomPeerID = self.parent._roomJoinPeerID else {
                    parent.logger.error("Missing MCPeerID for room")
                    continuation.resume(throwing: MultipeerServiceError.failedToJoinRoom)
                    parent._roomJoinContinuation = nil
                    return
                }
                guard peerID == roomPeerID else {
                    parent.logger.error("Mismatched MCPeerID for room join")
                    return
                }
                switch state {
                case .notConnected:
                    continuation.resume(returning: false)
                    parent._roomJoinContinuation = nil
                case .connecting:
                    parent.logger.trace("\(peerID) connecting...")
                case .connected:
                    continuation.resume(returning: true)
                    parent._roomJoinContinuation = nil
                @unknown default:
                    break
                }

            case .lookingForParticipants, .connectedAsHost:
                // Bug fix: transition to connectedAsHost when a peer connects
                switch state {
                case .connected:
                    parent.logger.trace("Peer \(peerID) connected as participant")
                    if parent.state == .lookingForParticipants {
                        parent.state = .connectedAsHost
                    }
                    Task { @MainActor [parent] in
                        parent?.peerConnectedHandler?(peerID)
                    }
                case .notConnected:
                    parent.logger.trace("Peer \(peerID) disconnected")
                    Task { @MainActor [parent] in
                        parent?.peerDisconnectedHandler?(peerID)
                    }
                case .connecting:
                    parent.logger.trace("Peer \(peerID) connecting...")
                @unknown default:
                    break
                }

            case .connectedAsParticipant:
                switch state {
                case .notConnected:
                    parent.logger.trace("Leader \(peerID) disconnected")
                    Task { @MainActor [parent] in
                        parent?.peerDisconnectedHandler?(peerID)
                    }
                case .connecting:
                    parent.logger.trace("Leader \(peerID) reconnecting...")
                case .connected:
                    parent.logger.trace("Leader \(peerID) connected")
                @unknown default:
                    break
                }

            default:
              parent.logger.trace("Session state change in state \(self.parent.state): peer \(peerID) -> \(state.rawValue)")
            }
        }

        func session(_ session: MCSession,
                     didReceive data: Data,
                     fromPeer peerID: MCPeerID) {
            do {
                let message = try LiveMultipeerService.decoder.decode(SessionMessage.self, from: data)
                Task { @MainActor [parent] in
                    parent?.messageHandler?(peerID, message)
                }
            } catch {
                parent.logger.warning("Failed to decode message from \(peerID): \(error)")
            }
        }

        func session(_ session: MCSession,
                     didReceive stream: InputStream,
                     withName streamName: String,
                     fromPeer peerID: MCPeerID) {
            parent.logger.warning("\(#function): Not Supported")
        }

        func session(_ session: MCSession,
                     didStartReceivingResourceWithName resourceName: String,
                     fromPeer peerID: MCPeerID,
                     with progress: Progress) {
            parent.logger.warning("\(#function): Not Supported")
        }

        func session(_ session: MCSession,
                     didFinishReceivingResourceWithName resourceName: String,
                     fromPeer peerID: MCPeerID,
                     at localURL: URL?,
                     withError error: (any Error)?) {
            parent.logger.warning("\(#function): Not Supported")
        }

    }

}
