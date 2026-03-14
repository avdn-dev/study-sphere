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
}

// MARK: - Payload Structs

struct JoinResponse: Codable, Sendable {
    let accepted: Bool
    let leaderDiscoveryTokenData: Data?
    let session: StudySession?
    let participants: [Participant]?
}

struct SessionStateUpdate: Codable, Sendable {
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
    let participantID: UUID
    let status: ParticipantStatus
    let source: DistractionEvent.Source?
}

struct PositionUpdate: Codable, Sendable {
    let entries: [Entry]

    struct Entry: Codable, Sendable {
        let participantID: UUID
        let x: Float
        let y: Float
        let status: ParticipantStatus
    }
}
