//
//  PersistentEventQueue.swift
//  
//
//  Created by Manish Kumar Mishra on 26/06/24.
//

import Foundation

class PersistentEventQueue {
  private let storageDirectory: URL

  private var fileNames = [String]()

  var count: Int {
    fileNames.count
  }

  init(storageDirectory: URL) {
    self.storageDirectory = storageDirectory
    initializeStorage()
  }

  private func initializeStorage() {
      do {
          try FileManager.default.createDirectory(atPath: storageDirectory.path, withIntermediateDirectories: true)
      } catch {
          perceptLog("Error trying to create caching folder \(error)")
      }

      do {
          fileNames = try FileManager.default.contentsOfDirectory(atPath: storageDirectory.path)
          fileNames.sort { Double($0)! < Double($1)! }
      } catch {
          perceptLog("Failed to load files for event queue \(error)")
      }
  }

  func getEvents(_ count: Int) -> [Data] {
    return loadEvents(count: count)
  }

  func remove(at index: Int) {
    guard index < count else { return }
    let fileName = fileNames.remove(at: index)
    deleteFile(at: storageDirectory.appendingPathComponent(fileName))
  }

  func pop(_ count: Int) {
    deleteEvents(count: count)
  }

  func add(_ eventData: Data) {
      do {
          let filename = "\(Date().timeIntervalSince1970)"
          try eventData.write(to: storageDirectory.appendingPathComponent(filename))
          fileNames.append(filename)
      } catch {
          perceptLog("Could not write file \(error)")
      }
  }

  func clear() {
    deleteDirectoryContents()
    initializeStorage()
  }

  private func loadEvents(count: Int) -> [Data] {
      var loadedEvents = [Data]()

      for fileName in fileNames.prefix(count) {
          let fileURL = storageDirectory.appendingPathComponent(fileName)
          do {
              if !FileManager.default.fileExists(atPath: fileURL.path) {
                  perceptLog("File \(fileURL) does not exist")
                  continue
              }
              let eventData = try Data(contentsOf: fileURL)

              loadedEvents.append(eventData)
          } catch {
              perceptLog("File \(fileURL) is corrupted \(error)")

              deleteFile(at: fileURL)
          }
      }

    return loadedEvents
  }

  private func deleteEvents(count: Int) {
      for _ in 0 ..< count {
          if fileNames.isEmpty { return }
          let removed = fileNames.remove(at: 0)

          deleteFile(at: storageDirectory.appendingPathComponent(removed))
      }
  }

  private func deleteFile(at url: URL) {
    if FileManager.default.fileExists(atPath: url.path) {
        do {
            try FileManager.default.removeItem(at: url)
        } catch {
            perceptLog("Failed to delete file at \(url.path) with error: \(error)")
        }
    }
  }

  private func deleteDirectoryContents() {
      deleteFile(at: storageDirectory)
  }
}
