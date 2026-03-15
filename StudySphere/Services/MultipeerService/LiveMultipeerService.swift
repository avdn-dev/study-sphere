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
            switch discoveredRooms {
            case .success, nil:
                discoveredRooms = .success(_roomsInfo)
            case .failure:
                return // Don't overwrite error state
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
        // Only reset to idle if we were actually browsing — don't clobber
        // .connectedAsParticipant which is set after a successful join.
        if state == .lookingForRooms {
            state = .idle
        }
        _roomsInfo = [:]
    }

    // MARK: - Joining A Room

    private var _roomJoinContinuation: CheckedContinuation<Bool, any Error>?
    private var _roomJoinPeerID: MCPeerID?

    private static let maxJoinAttempts = 3

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
            let joinRequestData = try Self.encoder.encode(joinRequest)

            for attempt in 1...Self.maxJoinAttempts {
                let session = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
                session.delegate = _delegate
                _session = session
                _roomJoinPeerID = info.peerID
                state = .joiningRoom
                logger.info("Join attempt \(attempt)/\(Self.maxJoinAttempts) — MCSession (local=\(self.peerID.displayName)) to host \(info.peerID.displayName)")

                let result = try await withCheckedThrowingContinuation { continuation in
                    _roomBrowser.invitePeer(
                        info.peerID,
                        to: session,
                        withContext: joinRequestData,
                        timeout: Self.timeout)
                    _roomJoinContinuation = continuation
                }

                if result {
                    logger.info("MC connection to room peer \(info.peerID) established (attempt \(attempt))")
                    state = .connectedAsParticipant
                    return true
                }

                logger.warning("Join attempt \(attempt)/\(Self.maxJoinAttempts) failed — transport never reached connected state")
                _session?.disconnect()
                _session = nil

                if attempt < Self.maxJoinAttempts {
                    try? await Task.sleep(for: .seconds(1))
                }
            }

            logger.error("All \(Self.maxJoinAttempts) join attempts to \(info.peerID) failed")
            _roomJoinPeerID = nil
            state = .idle
            return false
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
        let newSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        newSession.delegate = _delegate
        self._session = newSession
        logger.info("Host MCSession created (local=\(self.peerID.displayName), encryption=none)")
        self._roomAdvertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: RoomDiscoveryInfo(
                peerID: peerID,
                roomName: session.settings.sessionName,
                sessionID: session.id
            ).discoveryInfo,
            serviceType: Self.roomHostingServiceType
        )
        logger.trace("\(#function): Session updated successfully")
    }

    // MARK: - Session Resumption

    func resumeHosting(for session: StudySession) throws {
        // Tear down old MC objects
        _session?.disconnect()
        _roomAdvertiser?.stopAdvertisingPeer()

        // Create fresh MC session
        let newSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none)
        newSession.delegate = _delegate
        _session = newSession
        logger.info("Resumed MCSession (local=\(self.peerID.displayName), encryption=none)")
        _currentStudySession = session

        // Create fresh advertiser with session ID
        let advertiser = MCNearbyServiceAdvertiser(
            peer: peerID,
            discoveryInfo: RoomDiscoveryInfo(
                peerID: peerID,
                roomName: session.settings.sessionName,
                sessionID: session.id
            ).discoveryInfo,
            serviceType: Self.roomHostingServiceType
        )
        advertiser.delegate = _delegate
        _roomAdvertiser = advertiser
        advertiser.startAdvertisingPeer()

        state = .lookingForParticipants
        logger.info("Resumed hosting for session \(session.id)")
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
            let isRoomBrowser = browser === self.parent._roomBrowser
            let isParticipantBrowser = browser === self.parent._participantBrowser
            Task { @MainActor [parent] in
                guard let parent else { return }
                if isRoomBrowser {
                    parent._stopLookingForRooms(with: error)
                } else if isParticipantBrowser {
                    parent._stopLookingForParticipants(with: error)
                } else {
                    preconditionFailure()
                }
            }
        }

        func browser(_ browser: MCNearbyServiceBrowser,
                     foundPeer peerID: MCPeerID,
                     withDiscoveryInfo info: [String : String]?) {
            let isRoomBrowser = browser === self.parent._roomBrowser
            Task { @MainActor [parent] in
                guard let parent else { return }
                if isRoomBrowser {
                    guard let info = RoomDiscoveryInfo(peerID: peerID, discoveryInfo: info) else {
                        parent.logger.warning("Invalid info from room peer: \(peerID)")
                        return
                    }
                    parent._roomsInfo[peerID] = info
                } else {
                    guard let info = ParticipantDiscoveryInfo(peerID: peerID, discoveryInfo: info) else {
                        parent.logger.warning("Invalid info from participant peer: \(peerID)")
                        return
                    }
                    parent._participantsInfo[peerID] = info
                }
            }
        }

        func browser(_ browser: MCNearbyServiceBrowser,
                     lostPeer peerID: MCPeerID) {
            let isRoomBrowser = browser === self.parent._roomBrowser
            Task { @MainActor [parent] in
                guard let parent else { return }
                if isRoomBrowser {
                    guard parent._roomsInfo.keys.contains(peerID) else {
                        parent.logger.warning("Room Peer to remove is missing: \(peerID)")
                        return
                    }
                    parent._roomsInfo.removeValue(forKey: peerID)
                } else {
                    guard parent._participantsInfo.keys.contains(peerID) else {
                        parent.logger.warning("Room Participant to remove is missing: \(peerID)")
                        return
                    }
                    parent._participantsInfo.removeValue(forKey: peerID)
                }
            }
        }

        // Advertiser Delegate

        func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                        didNotStartAdvertisingPeer error: any Error) {
            let isRoomAdvertiser = advertiser === self.parent._roomAdvertiser
            Task { @MainActor [parent] in
                guard let parent else { return }
                if isRoomAdvertiser {
                    parent.logger.error("Failed to advertise room: \(error)")
                } else {
                    parent.logger.error("Unknown advertiser failed: \(error)")
                }
            }
        }

        func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                        didReceiveInvitationFromPeer peerID: MCPeerID,
                        withContext context: Data?,
                        invitationHandler: @escaping (Bool, MCSession?) -> Void) {
            let isRoomAdvertiser = advertiser === self.parent._roomAdvertiser
            let contextData = context
            let mcPeerID = peerID
            Task { @MainActor [parent] in
                guard let parent else {
                    invitationHandler(false, nil)
                    return
                }
                guard isRoomAdvertiser else {
                    parent.logger.warning("Unexpected advertiser received invitation")
                    invitationHandler(false, nil)
                    return
                }
                switch parent.state {
                case .lookingForParticipants, .connectedAsHost:
                    parent.logger.trace("Received participant invitation from: \(mcPeerID)")
                    guard let contextData else {
                        parent.logger.warning("\(mcPeerID) Missing context, ignoring")
                        invitationHandler(false, nil)
                        return
                    }
                    guard let joinRequestHandler = parent.joinRequestHandler else {
                        parent.logger.error("Received invitation but no handler set")
                        invitationHandler(false, nil)
                        return
                    }
                    let joinRequest: JoinRequest
                    do {
                        joinRequest = try LiveMultipeerService.decoder.decode(JoinRequest.self, from: contextData)
                    } catch {
                        parent.logger.warning("join request is malformed with error: \(error), ignoring")
                        invitationHandler(false, nil)
                        return
                    }
                    do {
                        guard try await joinRequestHandler(mcPeerID, joinRequest) else {
                            parent.logger.trace("Join request for \(mcPeerID) rejected by handler")
                            invitationHandler(false, nil)
                            return
                        }
                        let session = parent._session
                        parent.logger.info("Join request for \(mcPeerID) accepted — calling invitationHandler(true, session=\(session.debugDescription), connectedPeers=\(session?.connectedPeers.count ?? -1))")
                        invitationHandler(true, session)
                        parent.logger.info("invitationHandler returned for \(mcPeerID)")
                    } catch {
                        parent.logger.warning("Join request handler for \(mcPeerID) threw an error: \(error)")
                        invitationHandler(false, nil)
                    }
                default:
                  parent.logger.error("Invalid state for receiving an invitation: \(parent.state.rawValue)")
                    invitationHandler(false, nil)
                }
            }
        }

        // Session Delegate

        func session(_ session: MCSession,
                     peer peerID: MCPeerID,
                     didChange state: MCSessionState) {
            let stateLabel: String
            switch state {
            case .notConnected: stateLabel = "notConnected"
            case .connecting: stateLabel = "connecting"
            case .connected: stateLabel = "connected"
            @unknown default: stateLabel = "unknown(\(state.rawValue))"
            }
            Task { @MainActor [parent] in
                guard let parent else { return }
                guard session === parent._session else {
                    parent.logger.warning("Session state change for stale/unknown session: peer=\(peerID.displayName) state=\(stateLabel)")
                    return
                }

                parent.logger.info("MCSession state: peer=\(peerID.displayName) → \(stateLabel) (serviceState=\(parent.state.rawValue), connectedPeers=\(session.connectedPeers.map(\.displayName)))")

                switch parent.state {
                case .joiningRoom:
                    guard let continuation = parent._roomJoinContinuation else {
                        parent.logger.error("session(_:peer:didChange:): Missing room join continuation (state=\(stateLabel))")
                        return
                    }
                    guard let roomPeerID = parent._roomJoinPeerID else {
                        parent.logger.error("Missing MCPeerID for room")
                        continuation.resume(throwing: MultipeerServiceError.failedToJoinRoom)
                        parent._roomJoinContinuation = nil
                        return
                    }
                    guard peerID == roomPeerID else {
                        parent.logger.error("Mismatched MCPeerID for room join: expected=\(roomPeerID.displayName) got=\(peerID.displayName)")
                        return
                    }
                    switch state {
                    case .notConnected:
                        parent.logger.error("Join failed: MC transport to \(peerID.displayName) reached notConnected without ever connecting")
                        continuation.resume(returning: false)
                        parent._roomJoinContinuation = nil
                    case .connecting:
                        parent.logger.trace("MC transport to \(peerID.displayName) connecting...")
                    case .connected:
                        parent.logger.info("MC transport to \(peerID.displayName) connected successfully")
                        continuation.resume(returning: true)
                        parent._roomJoinContinuation = nil
                    @unknown default:
                        break
                    }

                case .lookingForParticipants, .connectedAsHost:
                    switch state {
                    case .connected:
                        parent.logger.info("Peer \(peerID.displayName) MC transport connected — will send queued join response")
                        if parent.state == .lookingForParticipants {
                            parent.state = .connectedAsHost
                        }
                        parent.peerConnectedHandler?(peerID)
                    case .notConnected:
                        parent.logger.warning("Peer \(peerID.displayName) MC transport disconnected (was \(parent.state.rawValue))")
                        if parent.state == .connectedAsHost,
                           parent._session?.connectedPeers.isEmpty == true {
                            parent.state = .lookingForParticipants
                        }
                        parent.peerDisconnectedHandler?(peerID)
                    case .connecting:
                        parent.logger.trace("Peer \(peerID.displayName) MC transport connecting...")
                    @unknown default:
                        break
                    }

                case .connectedAsParticipant:
                    switch state {
                    case .notConnected:
                        parent.logger.warning("Leader \(peerID.displayName) disconnected")
                        parent.peerDisconnectedHandler?(peerID)
                    case .connecting:
                        parent.logger.trace("Leader \(peerID.displayName) reconnecting...")
                    case .connected:
                        parent.logger.info("Leader \(peerID.displayName) connected")
                    @unknown default:
                        break
                    }

                default:
                    parent.logger.trace("Session state change in state \(parent.state.rawValue): peer \(peerID.displayName) → \(stateLabel)")
                }
            }
        }

        func session(_ session: MCSession,
                     didReceiveCertificate certificate: [Any]?,
                     fromPeer peerID: MCPeerID,
                     certificateHandler: @escaping (Bool) -> Void) {
            parent.logger.info("Received certificate from \(peerID.displayName), accepting (count=\(certificate?.count ?? 0))")
            certificateHandler(true)
        }

        func session(_ session: MCSession,
                     didReceive data: Data,
                     fromPeer peerID: MCPeerID) {
            let message: SessionMessage
            do {
                message = try LiveMultipeerService.decoder.decode(SessionMessage.self, from: data)
            } catch {
                // Logger is thread-safe; decode failure doesn't need MainActor
                parent.logger.warning("Failed to decode message from \(peerID): \(error)")
                return
            }
            Task { @MainActor [parent] in
                parent?.messageHandler?(peerID, message)
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
