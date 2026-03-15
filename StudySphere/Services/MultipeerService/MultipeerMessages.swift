//
//  MultipeerMessages.swift
//  StudySphere
//
//  Created by Matthew Yuen on 14/3/2026.
//

import Foundation

enum SessionMessage: Codable, Sendable {
    case joinResponse(JoinResponse)
    case sessionStateUpdate(SessionStateUpdate)
    case sessionStarted(SessionStarted)
    case sessionEnded(SessionEnded)
    case distractionBroadcast(DistractionBroadcast)
    case positionUpdate(PositionUpdate)
    case leaderLeaving(LeaderLeaving)
}

// MARK: - Payload Structs

struct JoinResponse: Codable, Sendable {
    let accepted: Bool
    let leaderParticipantID: UUID?
    let leaderDiscoveryTokenData: Data?
    let session: StudySession?
    let participants: [Participant]?
}

struct SessionStateUpdate: Codable, Sendable {
    let version: UInt64
    let participants: [Participant]
}

struct SessionStarted: Codable, Sendable {
    let startDate: Date
    let settings: SessionSettings
}

struct SessionEnded: Codable, Sendable {
    let endDate: Date
}

struct DistractionBroadcast: Codable, Sendable {
    let id: UUID
    let participantID: UUID
    let status: ParticipantStatus
    let source: DistractionEvent.Source?
}

struct PositionUpdate: Codable, Sendable {
    let sequence: UInt64
    let entries: [Entry]
    let centroidX: Float
    let centroidY: Float

    struct Entry: Codable, Sendable {
        let participantID: UUID
        let x: Float
        let y: Float
    }
}

struct LeaderLeaving: Codable, Sendable {
    let participantID: UUID
}
