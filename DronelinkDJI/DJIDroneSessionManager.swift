//
//  DronelinkDJIManager.swift
//  DronelinkDJI
//
//  Created by Jim McAndrew on 11/29/18.
//  Copyright © 2018 Dronelink. All rights reserved.
//

import Foundation
import os
import DronelinkCore
import DJISDK

public class DJIDroneSessionManager: NSObject {
    private let log = OSLog(subsystem: "DronelinkDJI", category: "DJIDroneSessionManager")
    
    private let delegates = MulticastDelegate<DroneSessionManagerDelegate>()
    private var _flyZoneState: DatedValue<DJIFlyZoneState>?
    private var _appActivationState: DatedValue<DJIAppActivationState>?
    private var _session: DJIDroneSession?
    private var videoPreviewerView: UIView?
    
    public override init() {
        super.init()
        
        guard let appKey = Bundle.main.object(forInfoDictionaryKey: SDK_APP_KEY_INFO_PLIST_KEY) as? String, !appKey.isEmpty else {
            fatalError("Please enter your DJI SDK app key in the info.plist")
        }
        
        DJISDKManager.registerApp(with: self)
        DJISDKManager.flyZoneManager()?.delegate = self
        DJISDKManager.appActivationManager().delegate = self
    }
}

extension DJIDroneSessionManager: DroneSessionManager {
    public func add(delegate: DroneSessionManagerDelegate) {
        delegates.add(delegate)
        if let session = _session {
            delegate.onOpened(session: session)
        }
    }
    
    public func remove(delegate: DroneSessionManagerDelegate) {
        delegates.remove(delegate)
    }
    
    public var session: DroneSession? { _session }
    
    public var statusMessages: [Kernel.Message]? {
        var messages: [Kernel.Message] = []
        
        if let message = _flyZoneState?.value.message {
            messages.append(message)
        }
        
        if let message = _appActivationState?.value.message {
            messages.append(message)
        }
        
        if let sessionStatusMessages = session?.state?.value.statusMessages {
            messages.append(contentsOf: sessionStatusMessages)
        }
        
        return messages
    }
}

extension DJIDroneSessionManager: DJISDKManagerDelegate {
    public func appRegisteredWithError(_ error: Error?) {
        if let error = error {
            os_log(.error, log: log, "DJI SDK Registered with error: %{public}s", error.localizedDescription)
        }
        else {
            os_log(.info, log: log, "DJI SDK Registered successfully")
        }
        
        DJISDKManager.startConnectionToProduct()
        DJISDKManager.setLocationDesiredAccuracy(kCLLocationAccuracyNearestTenMeters)
    }
    
    public func productConnected(_ product: DJIBaseProduct?) {
        if let drone = product as? DJIAircraft {
            _session = DJIDroneSession(drone: drone)
            delegates.invoke { $0.onOpened(session: self._session!) }
        }
    }
    
    public func productDisconnected() {
        if let session = _session {
            session.close()
            self._session = nil
            delegates.invoke { $0.onClosed(session: session) }
        }
    }
    
    public func componentConnected(withKey key: String?, andIndex index: Int) {
        _session?.componentConnected(withKey: key, andIndex: index)
    }
    
    public func componentDisconnected(withKey key: String?, andIndex index: Int) {
        _session?.componentDisconnected(withKey: key, andIndex: index)
    }
    
    public func didUpdateDatabaseDownloadProgress(_ progress: Progress) {
    }
}

extension DJIDroneSessionManager: DJIFlyZoneDelegate {
    public func flyZoneManager(_ manager: DJIFlyZoneManager, didUpdate state: DJIFlyZoneState) {
        _flyZoneState = DatedValue<DJIFlyZoneState>(value: state)
    }
    
    public func flyZoneManager(_ manager: DJIFlyZoneManager, didUpdateBasicDatabaseUpgradeProgress progress: Float, andError error: Error?) {}
    
    public func flyZoneManager(_ manager: DJIFlyZoneManager, didUpdateFlyZoneNotification notification: DJIFlySafeNotification) {}
}

extension DJIDroneSessionManager: DJIAppActivationManagerDelegate {
    public func manager(_ manager: DJIAppActivationManager!, didUpdate appActivationState: DJIAppActivationState) {
        _appActivationState = DatedValue<DJIAppActivationState>(value: appActivationState)
    }
}
