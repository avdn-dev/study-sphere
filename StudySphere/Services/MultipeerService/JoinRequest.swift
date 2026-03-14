//
//  JoinRequest.swift
//  StudySphere
//
//  Created by Matthew Yuen on 14/3/2026.
//

import Foundation

struct JoinRequest: Codable, Equatable, Sendable {
    let discoveryTokenData: Data
    let participantID: UUID
    let name: String
    let avatarSystemName: String
    let avatarImageData: Data?
    let peerIDData: Data

    init(discoveryTokenData: Data, participantID: UUID, name: String, avatarSystemName: String = "person.crop.circle.fill", avatarImageData: Data? = nil, peerIDData: Data) {
        self.discoveryTokenData = discoveryTokenData
        self.participantID = participantID
        self.name = name
        self.avatarSystemName = avatarSystemName
        self.avatarImageData = avatarImageData
        self.peerIDData = peerIDData
    }
}
