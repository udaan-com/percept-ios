//
//  PerceptEventQueue.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation

class FileBackedQueue {
    let queue: URL
    
    private var items = [String]()
    
    var depth: Int {
        items.count
    }

    init(queue: URL) {
        self.queue = queue
        setup()
    }
    
    private func setup() {
        do {
            try FileManager.default.createDirectory(atPath: queue.path, withIntermediateDirectories: true)
        } catch {
            perceptLog("Error trying to create caching folder \(error)")
        }


        do {
            items = try FileManager.default.contentsOfDirectory(atPath: queue.path)
            items.sort { Double($0)! < Double($1)! }
        } catch {
            perceptLog("Failed to load files for event queue \(error)")
        }
    }
    
    func peek(_ count: Int) -> [Data] {
        loadFiles(count)
    }

    func delete(index: Int) {
        if items.isEmpty { return }
        let removed = items.remove(at: index)

        deleteSafely(queue.appendingPathComponent(removed))
    }

    func pop(_ count: Int) {
        deleteFiles(count)
    }

    func add(_ contents: Data) {
        do {
            let filename = "\(Date().timeIntervalSince1970)"
            try contents.write(to: queue.appendingPathComponent(filename))
            items.append(filename)
        } catch {
            perceptLog("Could not write file \(error)")
        }
    }

    func clear() {
        deleteSafely(queue)
        setup()
    }
    
    private func loadFiles(_ count: Int) -> [Data] {
        var results = [Data]()

        for item in items {
            let itemURL = queue.appendingPathComponent(item)
            do {
                if !FileManager.default.fileExists(atPath: itemURL.path) {
                    perceptLog("File \(itemURL) does not exist")
                    continue
                }
                let contents = try Data(contentsOf: itemURL)

                results.append(contents)
            } catch {
                perceptLog("File \(itemURL) is corrupted \(error)")

                deleteSafely(itemURL)
            }

            if results.count == count {
                return results
            }
        }

        return results
    }
    
    private func deleteFiles(_ count: Int) {
        for _ in 0 ..< count {
            if items.isEmpty { return }
            let removed = items.remove(at: 0)

            deleteSafely(queue.appendingPathComponent(removed))
        }
    }
    
    private func deleteSafely(_ file: URL) {
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                perceptLog("Failed to delete file at \(file.path) with error: \(error)")
            }
        }
    }
    
}

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
    private let fileQueue: FileBackedQueue
    private let dispatchQueue: DispatchQueue
    private let retryDelay = 5.0
    private let maxRetryDelay = 30.0
    private let reachability: Reachability?
    
    private let api: PerceptApi
    
    var depth: Int {
            fileQueue.depth
    }
    
    init(_ config: PerceptConfig, _ storage: PerceptStorage, _ reachability: Reachability?) {
        self.config = config
        self.storage = storage
        self.reachability = reachability
        
        self.api = PerceptApi(config.apiKey)

        fileQueue = FileBackedQueue(queue: storage.getUrl(forKey: PerceptStorageKeys.eventQueue))
        dispatchQueue = DispatchQueue(label: "com.percept.eventQueue", target: .global(qos: .utility))
    }
    
    func clear() {
        fileQueue.clear()
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

        take(config.maxBatchSize) { payload in
            if !payload.events.isEmpty {
                self.eventHandler(payload)
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
        if fileQueue.depth >= config.maxQueueSize {
            perceptLog("Queue is full, dropping oldest event")
            // first is always oldest
            fileQueue.delete(index: 0)
        }

        var data: Data?
        do {
            data = try JSONEncoder().encode(event)
        } catch {
            perceptLog("Tried to queue unserialisable event \(error)")
            return
        }

        fileQueue.add(data!)
        perceptLog("Queued event '\(event.name)'. Depth: \(fileQueue.depth)")
        flushIfOverThreshold()
    }
    
    private func take(_ count: Int, completion: @escaping (PerceptEventConsumerPayload) -> Void) {
        dispatchQueue.async {
            self.isFlushingLock.withLock {
                if self.isFlushing {
                    return
                }
                self.isFlushing = true
            }

            let items = self.fileQueue.peek(count)

            var processing = [PerceptEvent]()
            let decoder = JSONDecoder()
            
            for item in items {
                guard let event = try? decoder.decode(PerceptEvent.self, from: item) else {
                    continue
                }
                processing.append(event)
            }

            completion(PerceptEventConsumerPayload(events: processing) { success in
                if success, items.count > 0 {
                    self.fileQueue.pop(items.count)
                    perceptLog("Completed!")
                }

                self.isFlushingLock.withLock {
                    self.isFlushing = false
                }
            })
        }
    }
    
    private func eventHandler(_ payload: PerceptEventConsumerPayload) {
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
        if fileQueue.depth >= config.flushAt {
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
            // We don't flush data if the queue is paused
            return false
        }

        if pausedUntil != nil, pausedUntil! > Date() {
            // We don't flush data if the queue is temporarily paused
            return false
        }

        return true
    }
    
}
