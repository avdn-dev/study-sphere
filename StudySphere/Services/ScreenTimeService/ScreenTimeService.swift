import Foundation
import FamilyControls
import VISOR

protocol ScreenTimeService: AnyObject {
    var isAuthorized: Bool { get }
    var isBlockedAppInUse: Bool { get }
    var blockedApps: FamilyActivitySelection { get set }

    func requestAuthorization() async throws
    func applyShields()
    func removeShields()
    func startMonitoring()
    func stopMonitoring()
    func clearBlockedAppFlag()
}
