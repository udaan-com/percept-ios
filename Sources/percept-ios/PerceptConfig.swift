//
//  PerceptConfig.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation

public struct PerceptConfig {
    public let apiKey: String
    public var flushAt = 20
    public var maxQueueSize = 1000
    public var maxBatchSize = 50
    public var flushIntervalSeconds: Double = 20
    public var captureAppLifecycleEvents = true
    public var debug = true
    
    public init(apiKey: String) {
        self.apiKey = apiKey;
    }
}
