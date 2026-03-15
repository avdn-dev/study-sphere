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

    /// Per-participant distraction count for the current session (for history entry)
    private var participantDistractionCounts: [UUID: Int] = [:]

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

    var isLeader: Bool {
        phase == .hosting || phase == .lobby || (phase == .active && multipeerService.isHost)
    }

    // MARK: - Leader Actions

    func hostSession(_ session: StudySession) async {
        activeSession = session
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

        // Persist session history entry before clearing state (leader only)
        if let session = activeSession {
            let startDate = sessionStartDate ?? endDate
            let durationSeconds = max(0, endDate.timeIntervalSince(startDate))
            let totalDistractions = participantDistractionCounts.values.reduce(0, +)

            let participantAnalytics: [ParticipantAnalytics] = participants.map { participant in
                let count = participantDistractionCounts[participant.id] ?? 0
                let focusScore = max(0, 1 - Double(count) * 0.1)
                return ParticipantAnalytics(
                    id: participant.id,
                    name: participant.name,
                    focusScore: focusScore,
                    focusDurationSeconds: durationSeconds,
                    distractionCount: count
                )
            }

            let sessionFocusScore: Double = {
                if participants.isEmpty { return 1 }
                let total = Double(participants.count)
                let avg = participantAnalytics.isEmpty ? 1 : participantAnalytics.reduce(0.0) { $0 + $1.focusScore } / Double(participantAnalytics.count)
                return min(1, max(0, avg))
            }()

            let entry = SessionHistoryEntry(
                id: UUID(),
                sessionName: session.settings.sessionName,
                date: endDate,
                durationSeconds: durationSeconds,
                participantCount: participants.count,
                distractionCount: totalDistractions,
                focusScore: sessionFocusScore,
                participantAnalytics: participantAnalytics
            )
            profileService.addHistoryEntry(entry)
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

    // MARK: - Distraction Reporting

    func reportLocalDistraction(status: ParticipantStatus, source: DistractionEvent.Source?) {
        guard let profile = profileService.profile else { return }

        // Update local participant status
        if let index = participants.firstIndex(where: { $0.id == profile.id }) {
            participants[index].status = status
        }

        participantDistractionCounts[profile.id, default: 0] += 1

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

        // Check if this is a returning participant within grace period
        if disconnectTimers[joinRequest.participantID] != nil {
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

                phase = .joined
                logger.info("Joined session successfully")
            } else {
                phase = .idle
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

            participantDistractionCounts[broadcast.participantID, default: 0] += 1

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
            // Could be leader disconnect on peer side
            if !isLeader && phase != .idle && phase != .ended {
                logger.info("Leader disconnected, cleaning up")
                cleanup()
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

    // MARK: - Cleanup

    private func cleanup() {
        positionBroadcastTask?.cancel()
        positionBroadcastTask = nil

        pendingJoinTimers.values.forEach { $0.cancel() }
        pendingJoinTimers.removeAll()

        disconnectTimers.values.forEach { $0.cancel() }
        disconnectTimers.removeAll()

        multipeerService.messageHandler = nil
        multipeerService.peerConnectedHandler = nil
        multipeerService.peerDisconnectedHandler = nil

        nearbyInteractionService.stopAllSessions()
        multipeerService.joinRequestHandler = nil
        multipeerService.disconnect()

        activeSession?.isActive = false
        activeSession = nil
        participants = []
        sessionStartDate = nil
        peerIDMap.removeAll()
        participantIDMap.removeAll()
        pendingJoinResponses.removeAll()
        leaderNIKey = nil
        stateVersion = 0
        lastReceivedStateVersion = 0
        positionSequence = 0
        lastPositionSequence = 0
        recentBroadcastIDs.removeAll()
        participantDistractionCounts.removeAll()
        phase = .ended
    }
}
