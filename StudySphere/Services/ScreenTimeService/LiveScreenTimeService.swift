import FamilyControls
import SwiftUI
import Foundation
import ManagedSettings
import VISOR
import DeviceActivity

extension DeviceActivityEvent.Name {
    static let something = Self("something")
}

@Observable
final class LiveScreenTimeService: ScreenTimeService {

    // MARK: - State

    var isAuthorized = false
    var isBlockedAppInUse = false
    var blockedApps = FamilyActivitySelection() { didSet {
        print("setting")
    }}

    let store = ManagedSettingsStore()
//    let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0), intervalEnd: DateComponents(hour: 23, minute: 59), repeats: false)
//    let center = DeviceActivityCenter()
    
    
    // MARK: - Shields

    func applyShields() {
        // TODO: Apply ManagedSettingsStore shields from selected apps
        //        let events: [DeviceActivityEvent.Name: DeviceActivityEvent] = [.something: DeviceActivityEvent(applications: blockedApps.applicationTokens, threshold: DateComponents(second: 0))]
        
        //        try center.startMonitoring(.init("something"), during: schedule, events: events)
        store.shield.applications = blockedApps.applicationTokens.isEmpty ? nil : blockedApps.applicationTokens
        store.shield.applicationCategories = blockedApps.categoryTokens.isEmpty ? nil : .specific(blockedApps.categoryTokens)
        store.shield.webDomains = blockedApps.webDomainTokens.isEmpty ? nil : blockedApps.webDomainTokens
    }

    func removeShields() {
        // TODO: Remove all shields from ManagedSettingsStore
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }

    // MARK: - Monitoring

    func startMonitoring() {
        // TODO: Start DeviceActivityMonitor for blocked app usage
    }

    func stopMonitoring() {
        // TODO: Stop DeviceActivityMonitor
    }

    func clearBlockedAppFlag() {
        isBlockedAppInUse = false
    }
}
