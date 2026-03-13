import FamilyControls
import SwiftUI
import Foundation
import ManagedSettings
import VISOR

@Observable
final class LiveScreenTimeService: ScreenTimeService {

    // MARK: - State

    var isAuthorized = false
    var isBlockedAppInUse = false
    var blockedApps = FamilyActivitySelection() { didSet {
        print("setting")
    }}

    // MARK: - Auth

    func requestAuthorization() async throws {
        // TODO: Call AuthorizationCenter.shared.requestAuthorization
    }

    // MARK: - Shields

    func applyShields() {
        // TODO: Apply ManagedSettingsStore shields from selected apps
    }

    func removeShields() {
        // TODO: Remove all shields from ManagedSettingsStore
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
