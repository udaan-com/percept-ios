//
//  Percept.swift
//  
//
//  Created by Manish Kumar Mishra on 25/06/24.
//

import Foundation
#if os(iOS)
    import UIKit
#endif

public enum PerceptUserProperty: String {
    case USER_ID = "user_id"
    case NAME = "name"
    case PHONE = "phone"
    case EMAIL = "email"
    case DEVICE_TOKEN = "device_token"
}

public final class Percept: NSObject {
    private var config: PerceptConfig;
    private var storage: PerceptStorage?;
    private var eventQueue: PerceptEventQueue?;
    private var api: PerceptApi?;
    private var reachability: Reachability?
    
    private let setupLock = NSLock();
    private let userIdLock = NSLock();
    private let uniqIdLock = NSLock();
    private let propsLock = NSLock();
    
    private var isInitialised = false;
    private var isInBackground = false;
    private var capturedAppInstalled = false
    private var deviceInfo: [String:String]?;
    private var uniqueId: String?;
    private var userId: String?;
    
    private var dispatchQueue = DispatchQueue(label: "com.percept.userQueue", target: .global(qos: .utility))
    
//    private var instance: PerceptSDK?;
    
    private init(_ config: PerceptConfig) {
        self.config = config;
    }
    
    deinit {
        self.reachability?.stopNotifier()
    }
    
    private var enabled = false;
    
    public static let shared: Percept = {
        let instance = Percept(PerceptConfig(apiKey: ""));
        return instance;
    }()
    
    public func setup(_ config: PerceptConfig) {
        setupLock.withLock {
            toogleLogging(config.debug)
        }
        
        if isInitialised {
            perceptLog("Percept is already setup. Returning!!")
            return;
        }
        
        self.config = config;
        
        do {
            reachability = try Reachability()
        } catch {
            // ignored
        }
        
        initUniqueid()
        
        initUserId()
        
        populateDeviceInfo()
        
        storage = PerceptStorage(config)
        
        api = PerceptApi(config.apiKey)
        
        eventQueue = PerceptEventQueue(config, storage!, reachability)
        
        addAppStateListeners()
        
        isInitialised = true;
        perceptLog("Setup done")
        
        eventQueue?.start()
    }
    
    public func setUserId(_ userId: String, withPerceptUserProps userProps: [PerceptUserProperty:String]? = [:], additionalProps: [String: String]? = [:]) {
        if !isEnabled(){
            return;
        }
        userIdLock.withLock {
            storage?.setString(forKey: PerceptStorageKeys.userId, value: userId)
            self.userId = userId;
            setCurrentUserProperties(withPerceptUserProps: userProps, additionalProps: additionalProps);
        }
    }
    
    public func setCurrentUserProperties(withPerceptUserProps userProps: [PerceptUserProperty:String]? = [:], additionalProps: [String: String]? = [:]) {
        if self.userId == nil {
            perceptLog("Set user property called without setting user id. Returning")
            return;
        }
        
        if self.api == nil {
            perceptLog("Api instance not found. Unable to set user property.")
            return;
        }
        let propsToSend: [String:String] = getUserPropsToSend(userProps: userProps, additionalProps: additionalProps)
        let userInfo = UserInfo(userId: self.userId!, data: propsToSend)
        dispatchQueue.async {
            self.api?.setUserData(userData: userInfo) { success in
                if !success {
                    perceptLog("Setting user property call failed");
                }
            }
        }
    }
    
    public func getGlobalProperties() -> [String: String] {
        guard let props = storage?.getDictionary(forKey: PerceptStorageKeys.globalProperties) as? [String: String] else {
            return [:]
        }
        return props;
    }
    
    public func setGlobalProperties(_ props: [String:String]) {
        if !isEnabled(){
            return;
        }
        
        if props.isEmpty {
            return;
        }
        
        propsLock.withLock {
            let existingGlobalProps = getGlobalProperties();
            let mergedProps = props.merging(existingGlobalProps) {_, new in new}
            storage?.setDictionary(forKey: PerceptStorageKeys.globalProperties, data: mergedProps)
        }
    }
    
    public func removeGlobalProperty(_ key: String) {
        propsLock.withLock {
            var existingGlobalProps = getGlobalProperties();
            existingGlobalProps.removeValue(forKey: key);
            storage?.setDictionary(forKey: PerceptStorageKeys.globalProperties, data: existingGlobalProps)
        }
    }
    
    public func capture(_ eventName: String) {
        capture(eventName, properties: nil);
    }
    
    public func capture(_ eventName: String, properties: [String:String]? = nil) {
        if !isEnabled(){
            return;
        }
        
        if eventQueue == nil {
            return
        }
        
        var propsToTrack = properties ?? [:]
        let globalProps = getGlobalProperties()
        let deviePropsToTrack = deviceInfo ?? [:]
        
        propsToTrack.merge(globalProps){ (current, new) in return current }
        propsToTrack.merge(deviePropsToTrack){ (current, new) in return new }
        
        propsToTrack["unique_id"] = self.uniqueId;
        propsToTrack["pi_client_ts"] = "\(Int(Date().timeIntervalSince1970)*1000)"
        propsToTrack["pi_client_unique_event_id"] = "EI-\(NSUUID().uuidString)"
        
        if self.userId != nil {
            propsToTrack["user_id"] = self.userId
        }
        
        let perceptEvent = PerceptEvent(name: eventName, data: propsToTrack);
        perceptLog("capture: \(perceptEvent)")
        
        eventQueue?.add(perceptEvent);
        
    }
    
    public func clear() {
        if !isEnabled() {
            return
        }
        storage?.reset()
        eventQueue?.clear()
        self.userId = nil
        initUniqueid()
    }
    
    public func flush() {
        if !isEnabled() {
            return
        }

        eventQueue?.flush()
    }
    
    public func close() {
        if !isEnabled() {
            return
        }

        setupLock.withLock {
            enabled = false
            eventQueue?.stop()
            eventQueue = nil
            config = PerceptConfig(apiKey: "")
            api = nil
            storage = nil
            #if !os(watchOS)
                self.reachability?.stopNotifier()
                reachability = nil
            #endif
            removeAppStateListeners()
            capturedAppInstalled = false
            isInBackground = false
            toogleLogging(false)
        }
    }
    
    private func getUserPropsToSend(userProps: [PerceptUserProperty:String]? = [:], additionalProps: [String: String]? = [:]) -> [String:String] {
        var propsToSend: [String:String] = [:]
        
        if additionalProps != nil, !additionalProps!.isEmpty {
            propsToSend.merge(additionalProps!) {(current, new) in return new}
        }
        
        if userProps != nil, !userProps!.isEmpty {
            let userPropsKeyValue = userProps!.map { key, value in
                  return (key.rawValue, value) // Use rawValue to get the String representation of the enum key
                }
            propsToSend.merge(userPropsKeyValue) { (current, new) in return new }
        }
        
        return propsToSend;
    }
    
    private func initUserId() {
        userIdLock.withLock {
            self.userId = storage?.getString(forKey:  PerceptStorageKeys.userId)
        }
    }
    
    private func initUniqueid() {
        uniqIdLock.withLock {
            var anonId = storage?.getString(forKey: PerceptStorageKeys.uniqueId);
            
            if anonId != nil {
                uniqueId = anonId;
                return;
            }
            anonId = NSUUID().uuidString;
            storage?.setString(forKey: PerceptStorageKeys.uniqueId, value: anonId!);
            uniqueId = anonId;
            return;
        }
    }
    
    private func isEnabled() -> Bool {
        if !isInitialised {
            perceptLog("SDK is not setup. This call will be ignored");
        }
        return isInitialised;
    }
    
    private func removeAppStateListeners() {
        let defaultCenter = NotificationCenter.default

        #if os(iOS)
            defaultCenter.removeObserver(self, name: UIApplication.didFinishLaunchingNotification, object: nil)
            defaultCenter.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
            defaultCenter.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        #endif
    }
    
    private func addAppStateListeners() {
        let defaultCenter = NotificationCenter.default
        
        #if os(iOS)
          defaultCenter.addObserver(self,
                                    selector: #selector(handleAppDidFinishLaunching),
                                    name: UIApplication.didFinishLaunchingNotification,
                                    object: nil)
          defaultCenter.addObserver(self,
                                    selector: #selector(handleAppDidEnterBackground),
                                    name: UIApplication.didEnterBackgroundNotification,
                                    object: nil)
          defaultCenter.addObserver(self,
                                    selector: #selector(handleAppDidBecomeActive),
                                    name: UIApplication.didBecomeActiveNotification,
                                    object: nil)
        #endif
      }
    
    @objc func handleAppDidFinishLaunching() {
        captureAppInstallLifecycle()
    }

    private func captureAppInstallLifecycle() {
        if !config.captureAppLifecycleEvents {
            return
        }

        let bundle = Bundle.main

        let versionName = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let versionCode = bundle.infoDictionary?["CFBundleVersion"] as? String

        // capture app installed/updated
        if !capturedAppInstalled {
            let userDefaults = UserDefaults.standard

            let previousVersion = userDefaults.string(forKey: "PIVersionKey")
            let previousVersionCode = userDefaults.string(forKey: "PIBuildKey")

            var props: [String: String] = [:]
            var event: String
            if previousVersionCode == nil {
                // installed
                event = "Application Installed"
            } else {
                event = "Application Updated"

                // Do not send version updates if its the same
                if previousVersionCode == versionCode {
                    return
                }

                if previousVersion != nil {
                    props["pi_previous_appVersion"] = previousVersion
                }
                props["pi_previous_appBuildId"] = previousVersionCode
            }

            var syncDefaults = false
            if versionName != nil {
                userDefaults.setValue(versionName, forKey: "PIVersionKey")
                syncDefaults = true
            }

            if versionCode != nil {
                userDefaults.setValue(versionCode, forKey: "PIBuildKey")
                syncDefaults = true
            }

            if syncDefaults {
                userDefaults.synchronize()
            }

            capture(event, properties: props)

            capturedAppInstalled = true
        }
    }
    
    @objc func handleAppDidEnterBackground() {
        captureAppBackgrounded()

        isInBackground = true
    }

    private func captureAppBackgrounded() {
        if !config.captureAppLifecycleEvents {
            return
        }
        capture("App Backgrounded")
    }
    
    @objc func handleAppDidBecomeActive() {
        isInBackground = false
        captureAppOpened()
    }
    
    private func captureAppOpened() {
        if !config.captureAppLifecycleEvents {
            return
        }
        capture("App Active")
    }
    
    private func populateDeviceInfo() {
        deviceInfo = [:]
        
        let infoDictionary = Bundle.main.infoDictionary

        if let appName = infoDictionary?[kCFBundleNameKey as String] {
            deviceInfo?["pi_app_name"] = appName as? String
        } else if let appName = infoDictionary?["CFBundleDisplayName"] {
            deviceInfo?["pi_app_name"] = appName as? String
        }
        if let appVersion = infoDictionary?["CFBundleShortVersionString"] {
            deviceInfo?["pi_app_version"] = appVersion as? String
        }
        if let appBuild = infoDictionary?["CFBundleVersion"] {
            deviceInfo?["pi_app_build"] = appBuild as? String
        }

        if Bundle.main.bundleIdentifier != nil {
            deviceInfo?["pi_app_namespace"] = Bundle.main.bundleIdentifier
        }
        deviceInfo?["pi_device_manufacturer"] = "Apple"
        
        #if os(iOS)
            let device = UIDevice.current
            deviceInfo?["pi_device_name"] = device.model
            deviceInfo?["pi_os_name"] = device.systemName
            deviceInfo?["pi_os_version"] = device.systemVersion
            
            deviceInfo?["pi_sdk_type"] = perceptSdkName;
            deviceInfo?["pi_sdk_version"] = perceptSdkVersion;
        #endif
    }
    
}

