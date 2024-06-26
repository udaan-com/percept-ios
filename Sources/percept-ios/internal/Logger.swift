//
//  Logger.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation

var isLoggingEnabled = false

func toogleLogging(_ enabled: Bool) {
    isLoggingEnabled = enabled
}

func perceptLog(_ message: String) {
    if !isLoggingEnabled {
        return
    }
    print("[PI] \(message)")
}
