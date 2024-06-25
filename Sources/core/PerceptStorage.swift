//
//  PerceptStorage.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation

enum PerceptStorageKeys: String {
    case uniqueId = "pi.uniqueId";
    case userId = "pi.userId";
    case globalProperties = "pi.globalProperties";
    case eventQueue = "pi.eventQueue";
}

func applicationSupportDirectoryURL() -> URL {
    let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return url.appendingPathComponent(Bundle.main.bundleIdentifier!)
}

class PerceptStorage {
    
    private let config: PerceptConfig;
    private let appStorageUrl: URL;
    
    init(_ config: PerceptConfig) {
        self.config = config;
        appStorageUrl = applicationSupportDirectoryURL();
        createDirectoryAtURLIfNeeded(url: appStorageUrl);
    }
    
    public func getUrl(forKey key: PerceptStorageKeys) -> URL {
        appStorageUrl.appendingPathComponent(key.rawValue)
    }
    
    public func setString(forKey key: PerceptStorageKeys, value: String) {
        let jsonObject = [key.rawValue: value]
        var data: Data?
        
        do {
            data = try JSONSerialization.data(withJSONObject: jsonObject)
        } catch {
            perceptLog("Failed to serialize key '\(key)' error: \(error)")
        }
        
        setData(forKey: key, data: data);
    }
    
    public func getString(forKey key: PerceptStorageKeys) -> String? {
        let value = getJson(forKey: key)
        
        if let stringValue = value as? String {
            return stringValue
        } else if let dictValue = value as? [String: String] {
            return dictValue[key.rawValue]
        }
        return nil
    }
    
    public func getDictionary(forKey key: PerceptStorageKeys) -> [String: String]? {
            getJson(forKey: key) as? [String: String]
        }

    public func setDictionary(forKey key: PerceptStorageKeys, data: [String: String]) {
        setJson(forKey: key, json: data)
    }
    
    public func reset() {
        // event queue will cleared by its clear handler
        delete(getUrl(forKey: PerceptStorageKeys.userId))
        delete(getUrl(forKey: PerceptStorageKeys.uniqueId))
        delete(getUrl(forKey: PerceptStorageKeys.globalProperties))
    }
    
    public func getBool(forKey key: PerceptStorageKeys) -> Bool? {
        let value = getJson(forKey: key)
        if let boolValue = value as? Bool {
            return boolValue
        } else if let dictValue = value as? [String: Bool] {
            return dictValue[key.rawValue]
        }
        return nil
    }

    public func setBool(forKey key: PerceptStorageKeys, data: Bool) {
        setJson(forKey: key, json: data)
    }
    
    private func setData(forKey key: PerceptStorageKeys, data: Data?) {
        var url = getUrl(forKey: key);
        
        do {
            if data == nil {
                delete(url);
                return;
            }
            try data?.write(to: url);
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            try url.setResourceValues(resourceValues)
        } catch {
            perceptLog("Storage write failed for key '\(key)' with error: \(error)")
        }
    }
    
    private func getData(forKey: PerceptStorageKeys) -> Data? {
        let url = getUrl(forKey: forKey)

        do {
            if FileManager.default.fileExists(atPath: url.path) {
                return try Data(contentsOf: url)
            }
        } catch {
            perceptLog("Reading data for key \(forKey): failed with error: \(error)")
        }
        return nil
    }
    
    private func setJson(forKey key: PerceptStorageKeys, json: Any) {
        var jsonObject: Any?

        if let dictionary = json as? [AnyHashable: Any] {
            jsonObject = dictionary
        } else if let array = json as? [Any] {
            jsonObject = array
        } else {
            // TRICKY: This is weird legacy behaviour storing the data as a dictionary
            jsonObject = [key.rawValue: json]
        }

        var data: Data?
        do {
            data = try JSONSerialization.data(withJSONObject: jsonObject!)
        } catch {
            perceptLog("Failed to serialize key '\(key)' with error: \(error)")
        }
        setData(forKey: key, data: data)
    }
    
    private func getJson(forKey key: PerceptStorageKeys) -> Any? {
        guard let data = getData(forKey: key) else { return nil }

        do {
            return try JSONSerialization.jsonObject(with: data)
        } catch {
            perceptLog("Failed to serialize key '\(key)' error: \(error)")
        }
        return nil
    }
    
    private func createDirectoryAtURLIfNeeded(url: URL) {
            if FileManager.default.fileExists(atPath: url.path) { return }
            do {
                try FileManager.default.createDirectory(atPath: url.path, withIntermediateDirectories: true)
            } catch {
                perceptLog("Storage directory creation failed \(error)")
            }
    }
    
    private func delete(_ file: URL) {
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                try FileManager.default.removeItem(at: file)
            } catch {
                perceptLog("Failed to delete file at \(file.path) with error: \(error)")
            }
        }
    }
}
