//
//  PerceptEventQueue.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation


class PerceptEventQueue {
    private let config: PerceptConfig
    private let storage: PerceptStorage
    private var paused: Bool = false
    private let pausedLock = NSLock()
    private var pausedUntil: Date?
    private var retryCount: TimeInterval = 0
    private var isFlushing = false
    private let isFlushingLock = NSLock()
    private var timer: Timer?
    private let timerLock = NSLock()
    private let persistentQueue: PersistentEventQueue
    private let dispatchQueue: DispatchQueue
    private let retryDelay = 5.0
    private let maxRetryDelay = 30.0
    private let reachability: Reachability?
    
    private let api: PerceptApi
    
    var count: Int {
        persistentQueue.count
    }
    
    init(_ config: PerceptConfig, _ storage: PerceptStorage, _ reachability: Reachability?) {
        self.config = config
        self.storage = storage
        self.reachability = reachability
        
        self.api = PerceptApi(config.apiKey)

        persistentQueue = PersistentEventQueue(storageDirectory: storage.getUrl(forKey: PerceptStorageKeys.eventQueue))
        dispatchQueue = DispatchQueue(label: "com.percept.eventQueue", target: .global(qos: .utility))
    }
    
    func clear() {
        persistentQueue.clear()
    }

    func stop() {
        timerLock.withLock {
            timer?.invalidate()
            timer = nil
        }
    }

    func flush() {
        if !canFlush() {
            perceptLog("Already flushing")
            return
        }

        process(config.maxBatchSize) { payload in
            if !payload.events.isEmpty {
                self.sendBatchedEvents(payload)
            } else {
                // there's nothing to be sent
                payload.completion(true)
            }
        }
    }
    
    func start() {
        reachability?.whenUnreachable = { _ in
           self.pausedLock.withLock {
               perceptLog("Queue is paused because network is unreachable")
               self.paused = true
           }
       }
        
        do {
            try reachability?.startNotifier()
        } catch {
            perceptLog("Error: Unable to monitor network reachability: \(error)")
        }
        
        timerLock.withLock {
            timer = Timer.scheduledTimer(withTimeInterval: config.flushIntervalSeconds, repeats: true, block: { _ in
                perceptLog("Inside timer: \(self.isFlushing)")
                if !self.isFlushing {
                    perceptLog("Inside timer flushing now")
                    self.flush()
                }
            })
        }
    }
    
    func add(_ event: PerceptEvent) {
        if persistentQueue.count >= config.maxQueueSize {
            perceptLog("Queue is full, dropping oldest event")
            persistentQueue.remove(at: 0)
        }

        var data: Data?
        do {
            data = try JSONEncoder().encode(event)
        } catch {
            perceptLog("Tried to queue unserialisable event \(error)")
            return
        }

        persistentQueue.add(data!)
        perceptLog("Queued event '\(event.name)'. Depth: \(persistentQueue.count)")
        flushIfOverThreshold()
    }
    
    private func process(_ count: Int, completion: @escaping (PerceptEventConsumerPayload) -> Void) {
        dispatchQueue.async {
            self.isFlushingLock.withLock {
                if self.isFlushing {
                    return
                }
                self.isFlushing = true
            }

            let items = self.persistentQueue.getEvents(count)

            var eventsToSend = [PerceptEvent]()
            let decoder = JSONDecoder()
            
            for item in items {
                guard let event = try? decoder.decode(PerceptEvent.self, from: item) else {
                    continue
                }
                eventsToSend.append(event)
            }

            completion(PerceptEventConsumerPayload(events: eventsToSend) { success in
                if success, items.count > 0 {
                    self.persistentQueue.pop(items.count)
                }

                self.isFlushingLock.withLock {
                    self.isFlushing = false
                }
            })
        }
    }
    
    private func sendBatchedEvents(_ payload: PerceptEventConsumerPayload) {
        perceptLog("Sending batch of \(payload.events.count) events to Percept")
        
        api.sendEvents(events: payload.events) { success in
            self.handleResult(success, payload)
        }
    }
    
    private func handleResult(_ success: Bool, _ payload: PerceptEventConsumerPayload) {

        let shouldRetry = !success

        if shouldRetry {
            retryCount += 1
            let delay = min(retryCount * retryDelay, maxRetryDelay)
            pauseFor(seconds: delay)
            perceptLog("Pausing queue consumption for \(delay) seconds due to \(retryCount) API failure(s).")
        } else {
            retryCount = 0
        }

        payload.completion(!shouldRetry)
    }

    
    private func flushIfOverThreshold() {
        if persistentQueue.count >= config.flushAt {
            flush()
        }
    }
    
    private func pauseFor(seconds: TimeInterval) {
            pausedUntil = Date().addingTimeInterval(seconds)
    }
    
    private func canFlush() -> Bool {
        if isFlushing {
            return false
        }

        if paused {
            return false
        }

        if pausedUntil != nil, pausedUntil! > Date() {
            return false
        }

        return true
    }
    
}
