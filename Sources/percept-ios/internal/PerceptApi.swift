//
//  PerceptApi.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation

import Alamofire

struct PerceptApiResponse: Decodable {
    var responseHTTPCode: Int;
}

struct PerceptApi {
    private let eventEndpoint = "https://app.perceptinsight.com/track/v1/event";
    private let userEndpoint = "https://app.perceptinsight.com/track/v1/user";
    private let token: String;
    
    init(_ apiKey: String) {
        token = apiKey;
    }
    
    func sendEvents(events: [PerceptEvent], completion: @escaping (_ success: Bool) -> Void) {
        let payload = EventPayload(events: events)
        
        let headers: HTTPHeaders = [
          "Authorization": "Bearer \(token)",
          "Content-Type": "application/json; charset=UTF-8"
        ]
        perceptLog("Sending events to percept")
        print(payload)
        
        AF.request(eventEndpoint, method: .post, parameters: payload, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseData { response in
                switch response.result {
                case .success:
                    completion(true)
                case let .failure(error):
                    completion(false)
                    print("Error capturing events: \(error)")
                }
            }
    }
    
    func setUserData(userData: UserInfo, completion: @escaping (_ success: Bool) -> Void) {
        let payload = userData
        
        let headers: HTTPHeaders = [
          "Authorization": "Bearer \(token)",
          "Content-Type": "application/json; charset=UTF-8"
        ]

        AF.request(userEndpoint, method: .post, parameters: payload, encoder: JSONParameterEncoder.default, headers: headers)
            .validate()
            .responseData { response in
                switch response.result {
                case .success:
                    completion(true)
                case let .failure(error):
                    completion(false)
                    print("Error capturing user: \(error)")
                }
            }
        
    }
}
