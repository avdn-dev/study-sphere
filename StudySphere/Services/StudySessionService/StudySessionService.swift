//
//  StudySessionService.swift
//  StudySphere
//
//  Created by Anh Nguyen on 14/3/2026.
//

import Foundation
import MultipeerConnectivity
import OSLog

// MARK: - Phase

enum StudySessionPhase: Equatable, Sendable {
    case idle
    case hosting
    case joining
    case joined
    case lobby
    case active
    case leaderReconnecting
    case ended
}

// MARK: - Protocol

protocol StudySessionService: AnyObject {
    var phase: StudySessionPhase { get }
    var activeSession: StudySession? { get }
    var participants: [Participant] { get }
    var isLeader: Bool { get }
    var sessionStartDate: Date? { get }

    // Leader actions
    func hostSession(_ session: StudySession) async
    func startSession() async
    func endSession() async

    // Peer actions
    func joinSession(room: RoomDiscoveryInfo, profile: UserProfile) async throws -> Bool
    func leaveSession() async
    func leaveSessionGracefully() async

    // Lifecycle
    func handleReturnToForeground()

    // Distraction reporting (any peer)
    func reportLocalDistraction(status: ParticipantStatus, source: DistractionEvent.Source?)
}

// MARK: - Live Implementation

@Observable
final class LiveStudySessionService: StudySessionService {

    private let multipeerService: any MultipeerService
    private let nearbyInteractionService: any NearbyInteractionService
    private let profileService: any ProfileService
    private let logger = Logger(subsystem: "study-sphere", category: "StudySessionService")

    // Mapping from participant UUID to MCPeerID for targeted sends
    private var peerIDMap: [UUID: MCPeerID] = [:]

    // Reverse mapping from MCPeerID to participant UUID
    private var participantIDMap: [MCPeerID: UUID] = [:]

    // Position broadcast task
    private var positionBroadcastTask: Task<Void, Never>?

    /// Responses queued until the MC connection is fully established
    private var pendingJoinResponses: [MCPeerID: SessionMessage] = [:]

    /// Timers that clean up ghost participants if MC connection never completes
    private var pendingJoinTimers: [MCPeerID: Task<Void, Never>] = [:]

    /// Grace period before permanently removing a disconnected peer
    private static let gracePeriodSeconds: TimeInterval = 15

    /// Timers for grace periods of disconnected peers
    private var disconnectTimers: [UUID: Task<Void, Never>] = [:]

    /// Monotonically increasing version for SessionStateUpdate ordering
    private var stateVersion: UInt64 = 0
    private var lastReceivedStateVersion: UInt64 = 0

    /// Monotonically increasing sequence for PositionUpdate ordering
    private var positionSequence: UInt64 = 0
    private var lastPositionSequence: UInt64 = 0

    /// Recently seen DistractionBroadcast IDs to prevent duplicate re-broadcasts
    private var recentBroadcastIDs: Set<UUID> = []
    private static let maxRecentBroadcastIDs = 50

    /// Key used for the peer's NI session with the leader (peer side only)
    private var leaderNIKey: String?

    /// Leader migration state
    private var leaderReconnectTimer: Task<Void, Never>?
    private var leaderDiscoveryTask: Task<Void, Never>?
    private static let leaderGracePeriodSeconds: TimeInterval = 30

    init(
        multipeerService: any MultipeerService,
        nearbyInteractionService: any NearbyInteractionService,
        profileService: any ProfileService
    ) {
        self.multipeerService = multipeerService
        self.nearbyInteractionService = nearbyInteractionService
        self.profileService = profileService
    }

    // MARK: - State

    private(set) var phase: StudySessionPhase = .idle
    private(set) var activeSession: StudySession?
    var participants: [Participant] = []
    private(set) var sessionStartDate: Date?

    private(set) var isLeader: Bool = false

    // MARK: - Leader Actions

    func hostSession(_ session: StudySession) async {
        activeSession = session
        isLeader = true
        phase = .hosting

        // Add self as first participant
        if let profile = profileService.profile {
            let selfParticipant = Participant(
                id: profile.id,
                peerIDData: profile.peerIDData,
                name: profile.name,
                avatarImageData: profile.avatarImageData,
                status: .focused
            )
            participants = [selfParticipant]
        }

        // Set up join request handler
        multipeerService.joinRequestHandler = { [weak self] peerID, joinRequest in
            guard let self else { return false }
            return self.handleJoinRequest(peerID: peerID, joinRequest: joinRequest)
        }

        // Set up event handlers
        multipeerService.messageHandler = { [weak self] peerID, message in
            self?.handleMessage(message, from: peerID)
        }
        multipeerService.peerConnectedHandler = { [weak self] peerID in
            self?.handlePeerConnected(peerID)
        }
        multipeerService.peerDisconnectedHandler = { [weak self] peerID in
            self?.handlePeerDisconnect(peerID)
        }

        logger.info("Hosting session: \(session.settings.sessionName)")
    }

    func startSession() async {
        guard isLeader, let session = activeSession else {
            logger.error("Cannot start session: not leader or no active session")
            return
        }

        let startDate = Date()
        sessionStartDate = startDate
        session.isActive = true
        phase = .active

        // Broadcast session started to all peers
        let message = SessionMessage.sessionStarted(
            SessionStarted(startDate: startDate, settings: session.settings)
        )
        do {
            try multipeerService.sendToAll(message, reliable: true)
        } catch {
            logger.error("Failed to broadcast session start: \(error)")
        }

        // Start position broadcast loop
        startPositionBroadcastLoop()

        logger.info("Session started at \(startDate)")
    }

    func endSession() async {
        guard isLeader else {
            logger.error("Cannot end session: not leader")
            return
        }

        let endDate = Date()
        let message = SessionMessage.sessionEnded(SessionEnded(endDate: endDate))
        do {
            try multipeerService.sendToAll(message, reliable: true)
        } catch {
            logger.error("Failed to broadcast session end: \(error)")
        }

        cleanup()
        logger.info("Session ended")
    }

    // MARK: - Peer Actions

    func joinSession(room: RoomDiscoveryInfo, profile: UserProfile) async throws -> Bool {
        phase = .joining

        // Prepare our NI session and get its discovery token to send to the leader.
        // Use a stable key we can reference later when running the session.
        let niKey = "leader-\(room.peerID.displayName)"
        leaderNIKey = niKey
        guard let niTokenData = nearbyInteractionService.prepareSession(for: niKey) else {
            logger.error("No NI discovery token available")
            phase = .idle
            return false
        }

        let joinRequest = JoinRequest(
            discoveryTokenData: niTokenData,
            participantID: profile.id,
            name: profile.name,
            avatarImageData: profile.avatarImageData,
            peerIDData: profile.peerIDData
        )

        // Set up event handlers BEFORE connecting so callbacks are ready
        // when the host sends the JoinResponse after connection.
        multipeerService.messageHandler = { [weak self] peerID, message in
            self?.handleMessage(message, from: peerID)
        }
        multipeerService.peerDisconnectedHandler = { [weak self] peerID in
            self?.handlePeerDisconnect(peerID)
        }

        let accepted = try await multipeerService.joinRoom(with: room, joinRequest: joinRequest)

        guard accepted else {
            multipeerService.messageHandler = nil
            multipeerService.peerDisconnectedHandler = nil
            phase = .idle
            return false
        }

        // Phase will transition to .joined when we receive the JoinResponse
        logger.info("Join request accepted, waiting for leader response")
        return true
    }

    func leaveSession() async {
        if isLeader {
            await endSession()
        } else {
            cleanup()
        }
        logger.info("Left session")
    }

    func leaveSessionGracefully() async {
        guard isLeader else {
            await leaveSession()
            return
        }
        guard let profile = profileService.profile else {
            await endSession()
            return
        }

        // Broadcast leader leaving to all peers so they can start migration
        let message = SessionMessage.leaderLeaving(
            LeaderLeaving(participantID: profile.id)
        )
        do {
            try multipeerService.sendToAll(message, reliable: true)
        } catch {
            logger.error("Failed to broadcast leader leaving: \(error)")
        }

        // Small delay to ensure message delivery
        try? await Task.sleep(for: .milliseconds(200))

        cleanup()
        logger.info("Leader left session gracefully")
    }

    // MARK: - Distraction Reporting

    func reportLocalDistraction(status: ParticipantStatus, source: DistractionEvent.Source?) {
        guard let profile = profileService.profile else { return }

        // Update local participant status
        if let index = participants.firstIndex(where: { $0.id == profile.id }) {
            participants[index].status = status
        }

        // Broadcast to all peers
        let message = SessionMessage.distractionBroadcast(
            DistractionBroadcast(
                id: UUID(),
                participantID: profile.id,
                status: status,
                source: source
            )
        )
        do {
            try multipeerService.sendToAll(message, reliable: true)
        } catch {
            logger.error("Failed to broadcast distraction: \(error)")
        }
    }

    // MARK: - Join Request Handling (Leader)

    private func handleJoinRequest(peerID: MCPeerID, joinRequest: JoinRequest) -> Bool {
        guard let session = activeSession else { return false }

        // Check if this is a returning participant (within grace period or during migration)
        if disconnectTimers[joinRequest.participantID] != nil ||
           (phase == .leaderReconnecting && participants.contains(where: { $0.id == joinRequest.participantID })) {
            return handleRejoin(peerID: peerID, joinRequest: joinRequest)
        }

        // Check capacity
        guard participants.count < session.maxSize else {
            logger.info("Rejecting \(joinRequest.name): session full (\(self.participants.count)/\(session.maxSize))")
            // Send rejection
            let response = SessionMessage.joinResponse(
                JoinResponse(accepted: false, leaderDiscoveryTokenData: nil, session: nil, participants: nil)
            )
            do {
                try multipeerService.send(response, to: [peerID], reliable: true)
            } catch {
                logger.error("Failed to send rejection: \(error)")
            }
            return false
        }

        // Build participant from join request
        let newParticipant = Participant(
            id: joinRequest.participantID,
            peerIDData: joinRequest.peerIDData,
            name: joinRequest.name,
            avatarSystemName: joinRequest.avatarSystemName,
            avatarImageData: joinRequest.avatarImageData,
            status: .focused
        )
        participants.append(newParticipant)
        peerIDMap[joinRequest.participantID] = peerID
        participantIDMap[peerID] = joinRequest.participantID

        // Prepare NI session for this peer and get the session's own token
        let peerIDString = joinRequest.participantID.uuidString
        let leaderTokenData = nearbyInteractionService.prepareSession(for: peerIDString)

        // Configure and run the session with the peer's discovery token
        nearbyInteractionService.runSession(for: peerIDString, peerDiscoveryTokenData: joinRequest.discoveryTokenData)

        // Queue the response — it will be sent once the MC connection is established
        let response = SessionMessage.joinResponse(
            JoinResponse(
                accepted: true,
                leaderDiscoveryTokenData: leaderTokenData,
                session: session,
                participants: participants
            )
        )
        pendingJoinResponses[peerID] = response

        // Start timeout to clean up if MC connection never completes
        pendingJoinTimers[peerID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(LiveMultipeerService.timeout + 5))
            guard !Task.isCancelled else { return }
            self?.cleanupFailedJoin(peerID: peerID)
        }

        // Transition to lobby if first peer joined
        if phase == .hosting {
            phase = .lobby
        }

        logger.info("\(joinRequest.name) joined session (\(self.participants.count)/\(session.maxSize))")
        return true
    }

    private func cleanupFailedJoin(peerID: MCPeerID) {
        guard pendingJoinResponses.removeValue(forKey: peerID) != nil else { return }
        guard let participantID = participantIDMap.removeValue(forKey: peerID) else { return }

        participants.removeAll { $0.id == participantID }
        nearbyInteractionService.stopSession(for: participantID.uuidString)
        peerIDMap.removeValue(forKey: participantID)
        pendingJoinTimers.removeValue(forKey: peerID)

        broadcastStateUpdate()

        logger.info("Cleaned up failed join for \(peerID)")
    }

    private func handleRejoin(peerID: MCPeerID, joinRequest: JoinRequest) -> Bool {
        let participantID = joinRequest.participantID

        // Cancel the grace period timer
        disconnectTimers[participantID]?.cancel()
        disconnectTimers.removeValue(forKey: participantID)

        // Restore peer maps with new MC connection
        peerIDMap[participantID] = peerID
        participantIDMap[peerID] = participantID

        // Restore participant status
        if let index = participants.firstIndex(where: { $0.id == participantID }) {
            participants[index].status = .focused
        }

        // Re-establish NI session
        let niKey = participantID.uuidString
        let leaderTokenData = nearbyInteractionService.prepareSession(for: niKey)
        nearbyInteractionService.runSession(for: niKey, peerDiscoveryTokenData: joinRequest.discoveryTokenData)

        // Queue rejoin response
        let response = SessionMessage.joinResponse(
            JoinResponse(
                accepted: true,
                leaderDiscoveryTokenData: leaderTokenData,
                session: activeSession,
                participants: participants
            )
        )
        pendingJoinResponses[peerID] = response

        // Start timeout for MC connection
        pendingJoinTimers[peerID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(LiveMultipeerService.timeout + 5))
            guard !Task.isCancelled else { return }
            self?.cleanupFailedJoin(peerID: peerID)
        }

        // If this is the first peer rejoining during migration, transition phase
        if phase == .leaderReconnecting {
            if activeSession?.isActive == true {
                phase = .active
                startPositionBroadcastLoop()
            } else {
                phase = .lobby
            }
            logger.info("Migration complete: first peer rejoined, phase restored")
        }

        logger.info("Peer \(participantID) rejoining session")
        return true
    }

    // MARK: - Message Handling

    private func handleMessage(_ message: SessionMessage, from peerID: MCPeerID) {
        switch message {

        case .joinResponse(let response):
            // Peer side: received acceptance/rejection from leader
            guard !isLeader else { return }

            if response.accepted {
                if let session = response.session {
                    activeSession = session
                }
                if let newParticipants = response.participants {
                    participants = newParticipants
                }

                // Run the pre-prepared NI session with the leader's token
                if let leaderTokenData = response.leaderDiscoveryTokenData,
                   let niKey = leaderNIKey {
                    nearbyInteractionService.runSession(
                        for: niKey,
                        peerDiscoveryTokenData: leaderTokenData
                    )
                }

                // If reconnecting after leader migration, restore appropriate phase
                if phase == .leaderReconnecting {
                    leaderReconnectTimer?.cancel()
                    leaderReconnectTimer = nil
                    leaderDiscoveryTask?.cancel()
                    leaderDiscoveryTask = nil
                    multipeerService.stopLookingForRooms()

                    if activeSession?.isActive == true {
                        phase = .active
                        logger.info("Reconnected to new leader, session active")
                    } else {
                        phase = .joined
                        logger.info("Reconnected to new leader, in lobby")
                    }
                } else {
                    phase = .joined
                    logger.info("Joined session successfully")
                }
            } else {
                if phase != .leaderReconnecting {
                    phase = .idle
                }
                logger.info("Join request rejected by leader")
            }

        case .sessionStateUpdate(let update):
            // Discard stale state updates
            guard update.version > lastReceivedStateVersion else {
                logger.trace("Ignoring stale state update (v\(update.version) <= v\(self.lastReceivedStateVersion))")
                return
            }
            lastReceivedStateVersion = update.version
            participants = update.participants
            logger.trace("Participants updated: \(update.participants.count) (v\(update.version))")

        case .sessionStarted(let started):
            // Peer side: session has begun
            guard !isLeader else { return }
            sessionStartDate = started.startDate
            activeSession?.isActive = true
            phase = .active
            logger.info("Session started (received from leader)")

        case .sessionEnded(let ended):
            // Peer side: session ended by leader
            guard !isLeader else { return }
            logger.info("Session ended at \(ended.endDate)")
            cleanup()

        case .distractionBroadcast(let broadcast):
            // Update participant status
            if let index = participants.firstIndex(where: { $0.id == broadcast.participantID }) {
                participants[index].status = broadcast.status
            }

            // If leader, re-broadcast to other peers (with deduplication)
            if isLeader {
                guard !recentBroadcastIDs.contains(broadcast.id) else { return }
                recentBroadcastIDs.insert(broadcast.id)
                if recentBroadcastIDs.count > Self.maxRecentBroadcastIDs {
                    recentBroadcastIDs.removeFirst()
                }

                let otherPeers = peerIDMap.values.filter { $0 != peerID }
                if !otherPeers.isEmpty {
                    do {
                        try multipeerService.send(
                            .distractionBroadcast(broadcast),
                            to: Array(otherPeers),
                            reliable: true
                        )
                    } catch {
                        logger.error("Failed to re-broadcast distraction: \(error)")
                    }
                }
            }

        case .positionUpdate(let update):
            // Peer side: apply positions from leader, discard out-of-order
            guard !isLeader else { return }
            guard update.sequence > lastPositionSequence else { return }
            lastPositionSequence = update.sequence
            for entry in update.entries {
                if let index = participants.firstIndex(where: { $0.id == entry.participantID }) {
                    participants[index].position = PeerPosition(
                        x: Double(entry.x),
                        y: Double(entry.y),
                        distanceFromCentroid: 0
                    )
                }
            }

        case .leaderLeaving(let leaving):
            // Peer side: leader is gracefully departing
            guard !isLeader else { return }
            logger.info("Leader \(leaving.participantID) is leaving gracefully")
            // Remove the departing leader from participants
            participants.removeAll { $0.id == leaving.participantID }
            enterLeaderMigrationState(departedLeaderID: leaving.participantID)
        }
    }

    // MARK: - Position Broadcast (Leader, ~10 Hz)

    private func startPositionBroadcastLoop() {
        guard isLeader else { return }
        positionBroadcastTask?.cancel()
        positionBroadcastTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { break }
                guard let self else { break }
                self.broadcastPositions()
            }
        }
    }

    private func broadcastPositions() {
        guard isLeader, let session = activeSession else { return }
        let positions = nearbyInteractionService.estimatedPositions

        var entries: [PositionUpdate.Entry] = []
        for i in participants.indices {
            let participant = participants[i]
            let peerIDString = participant.id.uuidString

            if let pos = positions[peerIDString] {
                // Update local state
                participants[i].position = pos

                // Check if outside radius — emit distraction broadcast rather than embedding in position
                if nearbyInteractionService.isPeerOutsideRadius(peerIDString, radiusMeters: session.settings.radiusMeters) {
                    if participants[i].status == .focused {
                        participants[i].status = .outsideCircle
                        let broadcast = DistractionBroadcast(
                            id: UUID(),
                            participantID: participant.id,
                            status: .outsideCircle,
                            source: .leftCircle
                        )
                        try? multipeerService.sendToAll(.distractionBroadcast(broadcast), reliable: true)
                    }
                }

                entries.append(PositionUpdate.Entry(
                    participantID: participant.id,
                    x: Float(pos.x),
                    y: Float(pos.y)
                ))
            } else if let profile = profileService.profile, participant.id == profile.id {
                // Leader's own position is at origin
                entries.append(PositionUpdate.Entry(
                    participantID: participant.id,
                    x: 0,
                    y: 0
                ))
            }
        }

        guard !entries.isEmpty else { return }

        positionSequence += 1
        let message = SessionMessage.positionUpdate(PositionUpdate(sequence: positionSequence, entries: entries))
        do {
            try multipeerService.sendToAll(message, reliable: false)
        } catch {
            logger.trace("Failed to broadcast positions: \(error)")
        }
    }

    // MARK: - Peer Connected Handling (Leader)

    private func handlePeerConnected(_ peerID: MCPeerID) {
        // Cancel the pending join timeout — connection succeeded
        pendingJoinTimers[peerID]?.cancel()
        pendingJoinTimers.removeValue(forKey: peerID)

        // Send the queued join response now that the connection is established
        if let response = pendingJoinResponses.removeValue(forKey: peerID) {
            do {
                try multipeerService.send(response, to: [peerID], reliable: true)
            } catch {
                logger.error("Failed to send join response to \(peerID): \(error)")
            }

            // Broadcast updated participants to existing peers
            broadcastStateUpdate()
        }
    }

    // MARK: - Disconnect Handling

    private func handlePeerDisconnect(_ peerID: MCPeerID) {
        guard let participantID = participantIDMap[peerID] else {
            logger.warning("Disconnected peer not found in participant map")
            // Leader disconnect on peer side — enter migration instead of cleanup
            if !isLeader && phase != .idle && phase != .ended && phase != .leaderReconnecting {
                logger.info("Leader disconnected, entering migration state")
                enterLeaderMigrationState(departedLeaderID: nil)
            }
            return
        }

        // Mark participant as reconnecting instead of removing immediately
        if let index = participants.firstIndex(where: { $0.id == participantID }) {
            participants[index].status = .reconnecting
        }

        // Stop NI session (will be re-established if peer reconnects)
        nearbyInteractionService.stopSession(for: participantID.uuidString)

        // Remove from MC maps (the MC connection is gone)
        peerIDMap.removeValue(forKey: participantID)
        participantIDMap.removeValue(forKey: peerID)

        // Broadcast updated state showing participant as reconnecting
        broadcastStateUpdate()

        // Start grace period timer
        disconnectTimers[participantID]?.cancel()
        disconnectTimers[participantID] = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.gracePeriodSeconds))
            guard !Task.isCancelled else { return }
            self?.finalizeDisconnect(participantID: participantID)
        }

        logger.info("Peer \(participantID) disconnected, grace period started (\(Self.gracePeriodSeconds)s)")
    }

    private func finalizeDisconnect(participantID: UUID) {
        participants.removeAll { $0.id == participantID }
        disconnectTimers.removeValue(forKey: participantID)

        // Broadcast updated state
        broadcastStateUpdate()

        // Revert to hosting phase if only the leader remains in lobby
        if isLeader && phase == .lobby && participants.count == 1 {
            phase = .hosting
        }

        logger.info("Grace period expired for \(participantID), removed from session")
    }

    private func broadcastStateUpdate() {
        guard isLeader else { return }
        stateVersion += 1
        let stateUpdate = SessionMessage.sessionStateUpdate(
            SessionStateUpdate(version: stateVersion, participants: participants)
        )
        do {
            try multipeerService.sendToAll(stateUpdate, reliable: true)
        } catch {
            logger.error("Failed to broadcast state update: \(error)")
        }
    }

    // MARK: - Leader Migration

    private func enterLeaderMigrationState(departedLeaderID: UUID?) {
        phase = .leaderReconnecting

        // Stop NI sessions (will be re-established after migration)
        nearbyInteractionService.stopAllSessions()
        leaderNIKey = nil

        // Disconnect dead MCSession
        multipeerService.disconnect()

        // Determine the new leader: lowest UUID among remaining participants
        // Exclude the departed leader if known
        guard let profile = profileService.profile else {
            cleanup()
            return
        }
        let candidates = participants.filter { p in
            p.status != .reconnecting && p.id != departedLeaderID
        }
        guard let electedLeader = candidates.min(by: { $0.id.uuidString < $1.id.uuidString }) else {
            logger.warning("No candidates for leader election, cleaning up")
            cleanup()
            return
        }

        logger.info("Leader election: elected \(electedLeader.name) (\(electedLeader.id))")

        if electedLeader.id == profile.id {
            becomeNewLeader()
        } else {
            waitForNewLeader()
        }

        // Start grace period timer
        leaderReconnectTimer?.cancel()
        leaderReconnectTimer = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.leaderGracePeriodSeconds))
            guard !Task.isCancelled else { return }
            self?.leaderGracePeriodExpired()
        }
    }

    private func becomeNewLeader() {
        guard let session = activeSession else {
            cleanup()
            return
        }

        isLeader = true
        logger.info("Becoming new leader for session \(session.id)")

        do {
            try multipeerService.resumeHosting(for: session)
        } catch {
            logger.error("Failed to resume hosting: \(error)")
            cleanup()
            return
        }

        // Set up event handlers (same as hostSession)
        multipeerService.joinRequestHandler = { [weak self] peerID, joinRequest in
            guard let self else { return false }
            return self.handleJoinRequest(peerID: peerID, joinRequest: joinRequest)
        }
        multipeerService.messageHandler = { [weak self] peerID, message in
            self?.handleMessage(message, from: peerID)
        }
        multipeerService.peerConnectedHandler = { [weak self] peerID in
            self?.handlePeerConnected(peerID)
        }
        multipeerService.peerDisconnectedHandler = { [weak self] peerID in
            self?.handlePeerDisconnect(peerID)
        }

        // Position broadcast will start when the first peer reconnects (in handleRejoin)
    }

    private func waitForNewLeader() {
        guard let session = activeSession,
              let profile = profileService.profile else {
            cleanup()
            return
        }

        logger.info("Waiting for new leader to advertise session \(session.id)")

        // Start browsing for rooms
        do {
            try multipeerService.startLookingForRooms(using: profile.name)
        } catch {
            logger.error("Failed to start looking for rooms: \(error)")
            cleanup()
            return
        }

        // Start polling for the room with matching session ID
        leaderDiscoveryTask?.cancel()
        leaderDiscoveryTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                guard let self else { break }

                guard case .success(let rooms) = self.multipeerService.discoveredRooms else {
                    continue
                }

                // Find a room advertising our session ID
                if let (_, roomInfo) = rooms.first(where: { $0.value.sessionID == session.id }) {
                    self.logger.info("Found new leader: \(roomInfo.displayName)")
                    await self.rejoinNewLeader(room: roomInfo, profile: profile)
                    break
                }
            }
        }
    }

    private func rejoinNewLeader(room: RoomDiscoveryInfo, profile: UserProfile) async {
        // Prepare NI session for new leader
        let niKey = "leader-\(room.peerID.displayName)"
        leaderNIKey = niKey
        guard let niTokenData = nearbyInteractionService.prepareSession(for: niKey) else {
            logger.error("No NI discovery token available for new leader")
            return
        }

        let joinRequest = JoinRequest(
            discoveryTokenData: niTokenData,
            participantID: profile.id,
            name: profile.name,
            avatarImageData: profile.avatarImageData,
            peerIDData: profile.peerIDData
        )

        // Set up message/disconnect handlers
        multipeerService.messageHandler = { [weak self] peerID, message in
            self?.handleMessage(message, from: peerID)
        }
        multipeerService.peerDisconnectedHandler = { [weak self] peerID in
            self?.handlePeerDisconnect(peerID)
        }

        do {
            let accepted = try await multipeerService.joinRoom(with: room, joinRequest: joinRequest)
            guard accepted else {
                logger.warning("New leader rejected rejoin request")
                return
            }
            // Phase will transition in handleMessage(.joinResponse) when response arrives
            logger.info("Rejoin request accepted by new leader")
        } catch {
            logger.error("Failed to rejoin new leader: \(error)")
        }
    }

    private func leaderGracePeriodExpired() {
        guard phase == .leaderReconnecting else { return }
        logger.info("Leader grace period expired, cleaning up")
        leaderDiscoveryTask?.cancel()
        leaderDiscoveryTask = nil
        multipeerService.stopLookingForRooms()
        cleanup()
    }

    // MARK: - Leader Resume (Return from Background)

    func handleReturnToForeground() {
        guard isLeader else { return }
        guard phase == .active || phase == .lobby else { return }
        guard multipeerService.connectedPeers.isEmpty else { return }

        // Check if we still have peers we expect to be connected to
        guard let profile = profileService.profile else { return }
        let otherParticipants = participants.filter { $0.id != profile.id }
        guard !otherParticipants.isEmpty else { return }

        logger.info("Leader returning from background with no connected peers")

        // Browse briefly to check if another leader took over
        leaderDiscoveryTask?.cancel()
        leaderDiscoveryTask = Task { [weak self] in
            guard let self else { return }
            guard let session = self.activeSession else { return }

            // Browse for rooms matching our session ID
            do {
                try self.multipeerService.startLookingForRooms(using: profile.name)
            } catch {
                self.logger.error("Failed to browse for existing leader: \(error)")
                self.resumeAsLeader()
                return
            }

            // Wait 3 seconds to find existing leader
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }

            if case .success(let rooms) = self.multipeerService.discoveredRooms,
               let (_, roomInfo) = rooms.first(where: { $0.value.sessionID == session.id }) {
                // Another leader exists — rejoin as peer
                self.logger.info("Another leader found, rejoining as peer")
                self.isLeader = false
                self.multipeerService.stopLookingForRooms()
                await self.rejoinNewLeader(room: roomInfo, profile: profile)
            } else {
                // No other leader — resume hosting
                self.multipeerService.stopLookingForRooms()
                self.resumeAsLeader()
            }
        }
    }

    private func resumeAsLeader() {
        guard let session = activeSession else { return }

        logger.info("Resuming as leader for session \(session.id)")

        do {
            try multipeerService.resumeHosting(for: session)
        } catch {
            logger.error("Failed to resume hosting: \(error)")
            return
        }

        // Re-attach all event handlers
        multipeerService.joinRequestHandler = { [weak self] peerID, joinRequest in
            guard let self else { return false }
            return self.handleJoinRequest(peerID: peerID, joinRequest: joinRequest)
        }
        multipeerService.messageHandler = { [weak self] peerID, message in
            self?.handleMessage(message, from: peerID)
        }
        multipeerService.peerConnectedHandler = { [weak self] peerID in
            self?.handlePeerConnected(peerID)
        }
        multipeerService.peerDisconnectedHandler = { [weak self] peerID in
            self?.handlePeerDisconnect(peerID)
        }

        // Restart position broadcast if session is active
        if phase == .active {
            startPositionBroadcastLoop()
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        positionBroadcastTask?.cancel()
        positionBroadcastTask = nil

        leaderReconnectTimer?.cancel()
        leaderReconnectTimer = nil
        leaderDiscoveryTask?.cancel()
        leaderDiscoveryTask = nil

        pendingJoinTimers.values.forEach { $0.cancel() }
        pendingJoinTimers.removeAll()

        disconnectTimers.values.forEach { $0.cancel() }
        disconnectTimers.removeAll()

        multipeerService.messageHandler = nil
        multipeerService.peerConnectedHandler = nil
        multipeerService.peerDisconnectedHandler = nil

        nearbyInteractionService.stopAllSessions()
        multipeerService.joinRequestHandler = nil
        multipeerService.stopLookingForRooms()
        multipeerService.disconnect()

        activeSession?.isActive = false
        activeSession = nil
        participants = []
        sessionStartDate = nil
        isLeader = false
        peerIDMap.removeAll()
        participantIDMap.removeAll()
        pendingJoinResponses.removeAll()
        leaderNIKey = nil
        stateVersion = 0
        lastReceivedStateVersion = 0
        positionSequence = 0
        lastPositionSequence = 0
        recentBroadcastIDs.removeAll()
        phase = .ended
    }
}
