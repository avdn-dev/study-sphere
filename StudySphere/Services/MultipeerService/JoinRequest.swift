//
//  JoinRequest.swift
//  StudySphere
//
//  Created by Matthew Yuen on 14/3/2026.
//

import NearbyInteraction

struct JoinRequest: Codable, Equatable {
    let discoveryToken: NIDiscoveryToken
    let participantID: UUID
    let name: String
    let avatarSystemName: String

    init(discoveryToken: NIDiscoveryToken, participantID: UUID, name: String, avatarSystemName: String = "person.circle.fill") {
        self.discoveryToken = discoveryToken
        self.participantID = participantID
        self.name = name
        self.avatarSystemName = avatarSystemName
    }

    enum CodingKeys: String, CodingKey {
        case discoveryToken
        case participantID
        case name
        case avatarSystemName
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let discoveryTokenData = try container.decode(Data.self, forKey: .discoveryToken)
        let discoveryToken = try NSKeyedUnarchiver.unarchivedObject(
            ofClass: NearbyInteraction.NIDiscoveryToken.self,
            from: discoveryTokenData)
        guard let discoveryToken else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "Failed to decode NIDiscoveryToken"))
        }
        self.discoveryToken = discoveryToken
        self.participantID = try container.decode(UUID.self, forKey: .participantID)
        self.name = try container.decode(String.self, forKey: .name)
        self.avatarSystemName = try container.decodeIfPresent(String.self, forKey: .avatarSystemName) ?? "person.circle.fill"
    }

    func encode(to encoder: any Encoder) throws {
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: discoveryToken,
            requiringSecureCoding: true)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .discoveryToken)
        try container.encode(participantID, forKey: .participantID)
        try container.encode(name, forKey: .name)
        try container.encode(avatarSystemName, forKey: .avatarSystemName)
    }

}
