//
//  JoinRequest.swift
//  StudySphere
//
//  Created by Matthew Yuen on 14/3/2026.
//

import NearbyInteraction

struct JoinRequest: Codable, Equatable {
    let discoveryToken: NIDiscoveryToken
    
    enum CodingKeys: String, CodingKey {
        case discoveryToken
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
    }
    
    func encode(to encoder: any Encoder) throws {
        let data = try NSKeyedArchiver.archivedData(
            withRootObject: discoveryToken,
            requiringSecureCoding: true)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .discoveryToken)
    }
    
}
