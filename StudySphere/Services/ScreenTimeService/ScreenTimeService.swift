import Foundation
import FamilyControls
import VISOR

protocol ScreenTimeService: AnyObject {
    var blockedApps: FamilyActivitySelection { get set }

    func applyShields()
    func removeShields()
}
