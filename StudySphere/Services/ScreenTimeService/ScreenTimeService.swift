import Foundation
import VISOR

@Stubbable
@Spyable
protocol ScreenTimeService: AnyObject {
    var isAuthorized: Bool { get }
    var isBlockedAppInUse: Bool { get }

    func requestAuthorization() async throws
    func applyShields()
    func removeShields()
    func startMonitoring()
    func stopMonitoring()
    func clearBlockedAppFlag()
}

#if DEBUG
extension SpyScreenTimeService.Call: Equatable {
    public static func == (lhs: SpyScreenTimeService.Call, rhs: SpyScreenTimeService.Call) -> Bool {
        String(describing: lhs) == String(describing: rhs)
    }
}
#endif
