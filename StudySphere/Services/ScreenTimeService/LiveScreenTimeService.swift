import FamilyControls
import SwiftUI
import Foundation
import ManagedSettings
import VISOR
import DeviceActivity

@Observable
final class LiveScreenTimeService: ScreenTimeService {

    // MARK: - State

    var blockedApps = FamilyActivitySelection()
    

    private let store = ManagedSettingsStore()
    // MARK: - Shields

    func applyShields() {
        store.shield.applications = blockedApps.applicationTokens.isEmpty ? nil : blockedApps.applicationTokens
        store.shield.applicationCategories = blockedApps.categoryTokens.isEmpty ? nil : .specific(blockedApps.categoryTokens)
        store.shield.webDomains = blockedApps.webDomainTokens.isEmpty ? nil : blockedApps.webDomainTokens
    }

    func removeShields() {
        store.shield.applications = nil
        store.shield.applicationCategories = nil
        store.shield.webDomains = nil
    }
}
