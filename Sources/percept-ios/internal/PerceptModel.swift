//
//  PerceptModel.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation

struct PerceptEventConsumerPayload {
    let events: [PerceptEvent]
    let completion: (Bool) -> Void
}

struct PerceptEvent: Codable {
    var name: String
    var data: [String: String] = [:]
    var multiData: [String: [String]] = [:]

    // Optional initializer for decoding from JSON
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        name = try container.decode(String.self, forKey: .name)
//        data = try container.decodeIfPresent([String: String].self, forKey: .data) ?? [:]
//        multiData = try container.decodeIfPresent([String: [String]].self, forKey: .multiData) ?? [:]
//    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(data, forKey: .data)
        try container.encode(multiData, forKey: .multiData)
    }

    private enum CodingKeys: String, CodingKey {
        case name = "name"
        case data = "data"
        case multiData = "multiData"
    }
}

struct EventPayload: Codable {
    var events: [PerceptEvent]
}

struct UserInfo: Codable {
    var userId: String
    var data: [String: String] = [:]
    var multiData: [String: [String]] = [:]

    // Optional initializer for decoding from JSON
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        userId = try container.decode(String.self, forKey: .userId)
//        data = try container.decodeIfPresent([String: String].self, forKey: .data) ?? [:]
//        multiData = try container.decodeIfPresent([String: [String]].self, forKey: .multiData) ?? [:]
//      }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try container.encode(data, forKey: .data)
        try container.encode(multiData, forKey: .multiData)
    }

    private enum CodingKeys: String, CodingKey {
        case userId = "userId"
        case data = "data"
        case multiData = "multiData"
    }
}
